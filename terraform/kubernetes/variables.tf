variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context to use (leave empty for current context)"
  type        = string
  default     = ""
}

# MetalLB
variable "metallb_version" {
  description = "MetalLB manifest version"
  type        = string
  default     = "v0.14.9"
}

variable "metallb_ip_pool_name" {
  description = "Name for the MetalLB IP address pool"
  type        = string
  default     = "lab-pool"
}

variable "metallb_ip_range" {
  description = "IP range MetalLB will assign to LoadBalancer services"
  type        = string
  default     = "10.69.5.240-10.69.5.245"
}

# HAProxy ingress
variable "haproxy_ingress_version" {
  description = "HAProxy Kubernetes Ingress Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

# nginx test deployment
variable "deploy_nginx_test" {
  description = "Whether to deploy the nginx test workload"
  type        = bool
  default     = true
}
