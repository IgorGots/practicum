########################
# Imported from .env
########################
variable IAM_TOKEN {
    sensitive = true
}

variable "cloud_id" {
  type = string
  description = "Project cloud_id"
}


########################
# installation variables
########################
output "folder_id" {
  value = yandex_resourcemanager_folder.practicum-folder.id
  sensitive = false
}
output "kube_cluster_id" {
  value = yandex_kubernetes_cluster.practicum-kubernetes.id
  sensitive = false
}
output "gitlab_nat_ip" {
  value = yandex_compute_instance.practicum-gitlab.network_interface[0].nat_ip_address
  sensitive = false
}