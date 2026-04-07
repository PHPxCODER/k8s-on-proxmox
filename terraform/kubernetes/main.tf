# ─── MetalLB ─────────────────────────────────────────────────────────────────

# Enable strict ARP in kube-proxy (required by MetalLB in L2 mode)
resource "kubernetes_config_map_v1_data" "kube_proxy_strict_arp" {
  metadata {
    name      = "kube-proxy"
    namespace = "kube-system"
  }

  data = {
    "config.conf" = <<-CONF
      apiVersion: kubeproxy.config.k8s.io/v1alpha1
      kind: KubeProxyConfiguration
      ipvs:
        strictARP: true
    CONF
  }

  force = true
}

resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/enforce"         = "privileged"
      "pod-security.kubernetes.io/enforce-version" = "latest"
    }
  }
}

# MetalLB installed via Helm (recommended for >= 0.13)
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = kubernetes_namespace.metallb_system.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  depends_on = [kubernetes_namespace.metallb_system]
}

# IP address pool — MetalLB assigns these IPs to LoadBalancer services
resource "kubernetes_manifest" "metallb_ip_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = var.metallb_ip_pool_name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }

  depends_on = [helm_release.metallb]
}

# L2 advertisement — announces IPs from the pool over Layer 2 (ARP)
resource "kubernetes_manifest" "metallb_l2_advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advert"
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = {
      ipAddressPools = [var.metallb_ip_pool_name]
    }
  }

  depends_on = [kubernetes_manifest.metallb_ip_pool]
}

# ─── HAProxy Ingress Controller ───────────────────────────────────────────────

resource "kubernetes_namespace" "haproxy_controller" {
  metadata {
    name = "haproxy-controller"
  }
}

resource "helm_release" "haproxy_ingress" {
  name             = "haproxy-ingress"
  repository       = "https://haproxytech.github.io/helm-charts"
  chart            = "kubernetes-ingress"
  version          = var.haproxy_ingress_version != "" ? var.haproxy_ingress_version : null
  namespace        = kubernetes_namespace.haproxy_controller.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [kubernetes_manifest.metallb_l2_advertisement]
}

# ─── nginx test deployment ────────────────────────────────────────────────────

resource "kubernetes_deployment_v1" "nginx_test" {
  count = var.deploy_nginx_test ? 1 : 0

  metadata {
    name      = "nginx-test"
    namespace = "default"
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx_test" {
  count = var.deploy_nginx_test ? 1 : 0

  metadata {
    name      = "nginx-service"
    namespace = "default"
  }

  spec {
    selector = { app = "nginx" }
    type     = "LoadBalancer"

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_manifest.metallb_l2_advertisement]
}

# Example Ingress routing nginx.lab.local → nginx-service via HAProxy
resource "kubernetes_ingress_v1" "nginx_ingress" {
  count = var.deploy_nginx_test ? 1 : 0

  metadata {
    name      = "nginx-ingress"
    namespace = "default"
    annotations = {
      "ingress.class" = "haproxy"
    }
  }

  spec {
    rule {
      host = "nginx.lab.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.nginx_test[0].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.haproxy_ingress]
}
