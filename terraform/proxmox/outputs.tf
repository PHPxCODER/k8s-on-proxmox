output "master_ip" {
  description = "IP address of the Kubernetes master node"
  value       = var.master_ip
}

output "worker_ips" {
  description = "IP addresses of Kubernetes worker nodes"
  value       = var.worker_ips
}

output "master_ssh" {
  description = "SSH command to connect to master node"
  value       = "ssh ${var.vm_username}@${var.master_ip}"
}

output "worker_ssh" {
  description = "SSH commands to connect to worker nodes"
  value = [
    for i, ip in var.worker_ips :
    "ssh ${var.vm_username}@${ip}"
  ]
}

output "next_steps" {
  description = "Manual steps after Terraform apply"
  value       = <<-EOT
    VMs are provisioned and Kubernetes prerequisites are installed via cloud-init.

    Next steps:
      1. SSH to master:  ssh ${var.vm_username}@${var.master_ip}
      2. Initialize cluster:
           sudo kubeadm init --pod-network-cidr=10.244.0.0/16
      3. Configure kubectl:
           mkdir -p $HOME/.kube
           sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
           sudo chown $(id -u):$(id -g) $HOME/.kube/config
      4. Install Flannel CNI:
           kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
      5. Copy join command, then run on each worker node with sudo.
      6. Copy kubeconfig to your local machine and run:
           cd ../kubernetes && terraform apply
  EOT
}
