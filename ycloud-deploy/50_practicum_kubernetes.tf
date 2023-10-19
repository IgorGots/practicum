####################################################################################################################################################
# folder for project
resource "yandex_resourcemanager_folder" "practicum-folder" {
  cloud_id    = var.cloud_id
  name        = "practicum-folder"
  description = "folder for ycloud-deploy course on practicum"
}

####################################################################################################################################################
# create accounts for kubernetes management
resource "yandex_iam_service_account" "terraform-sa" {
  name = "${yandex_resourcemanager_folder.practicum-folder.name}-tf-sa"
  folder_id = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "tf-sa-editor" {
  member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
  role        = "editor"
  folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
 member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
 role      = "container-registry.images.puller"
 folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "alb-editor" {
 member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
 role      = "alb.editor"
 folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "vpc-publicAdmin" {
 member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
 role      = "vpc.publicAdmin"
 folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "certificate-manager-certificates-downloader" {
 member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
 role      = "certificate-manager.certificates.downloader"
 folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "compute-viewer" {
 member     = "serviceAccount:${yandex_iam_service_account.terraform-sa.id}"
 role      = "compute.viewer"
 folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
}

####################################################################################################################################################
# networks for cluster
resource "yandex_vpc_network" "practicum-network" {
  name          = "${yandex_resourcemanager_folder.practicum-folder.name}-network"
  description   = "network for practicum kubernetes"
  folder_id     = "${yandex_resourcemanager_folder.practicum-folder.id}"
}
resource "yandex_vpc_subnet" "practicum-subnet-a" {
  name          = "${yandex_resourcemanager_folder.practicum-folder.name}-subnet"
  v4_cidr_blocks    = ["10.2.0.0/16"]
  zone              = "ru-central1-a"
  network_id        = "${yandex_vpc_network.practicum-network.id}"
  folder_id         = "${yandex_resourcemanager_folder.practicum-folder.id}"
}

####################################################################################################################################################
# security group
resource "yandex_vpc_security_group" "practicum-security-group" {
    name          = "${yandex_resourcemanager_folder.practicum-folder.name}-security-group"
    folder_id = "${yandex_resourcemanager_folder.practicum-folder.id}"
    network_id    = yandex_vpc_network.practicum-network.id

    ingress {
        protocol       = "TCP"
        v4_cidr_blocks = ["0.0.0.0/0"]
        port           = 443
    }
    ingress {
        protocol       = "TCP"
        v4_cidr_blocks = ["0.0.0.0/0"]
        port           = 80
    }

    ingress {
        protocol           = "ANY"
        predefined_target  = "self_security_group"
        from_port          = 0
        to_port            = 65535
    }
    ingress {
        protocol           = "ANY"
        v4_cidr_blocks     = ["10.96.0.0/16", "10.112.0.0/16"]
        from_port          = 0
        to_port            = 65535
    }
    ingress {
        protocol           = "TCP"
        v4_cidr_blocks     = ["198.18.235.0/24", "198.18.248.0/24"]
        from_port          = 0
        to_port            = 65535
    }

    egress {
        protocol       = "ANY"
        v4_cidr_blocks = ["0.0.0.0/0"]
        from_port      = 0
        to_port        = 65535
    }

    ingress {
        protocol           = "ICMP"
        v4_cidr_blocks     = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
    }

}

####################################################################################################################################################
# https://cloud.yandex.ru/docs/managed-kubernetes/operations/kubernetes-cluster/kubernetes-cluster-create
resource "yandex_kubernetes_cluster" "practicum-kubernetes" {
    name        = "${yandex_resourcemanager_folder.practicum-folder.name}-kubecluster"
    folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
    network_id  = yandex_vpc_network.practicum-network.id

    master {
        version = "1.24"
        zonal {
            zone      = yandex_vpc_subnet.practicum-subnet-a.zone
            subnet_id = yandex_vpc_subnet.practicum-subnet-a.id
        }
        public_ip = true
        security_group_ids = ["${yandex_vpc_security_group.practicum-security-group.id}"]
    }

    service_account_id      = yandex_iam_service_account.terraform-sa.id
    node_service_account_id = yandex_iam_service_account.terraform-sa.id

    release_channel = "RAPID"

    depends_on = [
        yandex_resourcemanager_folder_iam_member.tf-sa-editor,
        yandex_resourcemanager_folder_iam_member.images-puller
    ]
}


####################################################################################################################################################
# work group of kube nodes
resource "yandex_kubernetes_node_group" "practicum-node-group" {
    name        = "${yandex_resourcemanager_folder.practicum-folder.name}-kuber-nodes"
    cluster_id  = "${yandex_kubernetes_cluster.practicum-kubernetes.id}"

    instance_template {
      # platform_id = "standard-v2"
      network_interface {
        subnet_ids          = ["${yandex_vpc_subnet.practicum-subnet-a.id}"]
        security_group_ids  = ["${yandex_vpc_security_group.practicum-security-group.id}"]
        ipv4                = true
        nat                 = true
      }
      resources {
        memory = 4
        cores  = 2
      }
      scheduling_policy {
        preemptible         = true
      }
      metadata = {
        ssh-keys            = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
      }
    }
    scale_policy {
      auto_scale {
        initial             = 1
        min                 = 1
        max                 = 2
      }
    }


}

resource "yandex_compute_instance" "practicum-gitlab" {
    name        = "gitlab"
    hostname    = "gitlab"
    platform_id = "standard-v3"
    folder_id   = yandex_resourcemanager_folder.practicum-folder.id
    zone        = yandex_vpc_subnet.practicum-subnet-a.zone

    resources {
      cores     = 2
      memory    = 8
    }

    boot_disk {
      initialize_params {
        image_id = "fd8km640ctfepo3v3ck5"
        size      = 30
      }
    }

    network_interface {
      subnet_id   = yandex_vpc_subnet.practicum-subnet-a.id
      nat         = true
    }

    scheduling_policy {
      preemptible   = true
    }

    metadata = {
      ## UBUNTU USER FOR GITLAB MANAGED VPC
      ssh-keys            = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
      serial-port-enable  = 1
    }
}

resource "yandex_alb_load_balancer" "practicum-balancer" {
    name        = "${yandex_resourcemanager_folder.practicum-folder.name}-balancer"
    folder_id   = "${yandex_resourcemanager_folder.practicum-folder.id}"
    network_id  = yandex_vpc_network.practicum-network.id

    allocation_policy {
        location {
            zone_id   = yandex_vpc_subnet.practicum-subnet-a.zone
            subnet_id = yandex_vpc_subnet.practicum-subnet-a.id
        }
    }

    # listener {
    #     name = "${yandex_resourcemanager_folder.practicum-folder.name}-listener"
    #     endpoint {
    #         address {
    #             external_ipv4_address {
    #             }
    #         }
    #         ports = [ 8080 ]
    #     }

    #     # http {
    #     #     handler {
    #     #         http_router_id = yandex_alb_http_router.test-router.id
    #     #     }
    #     # }
    # }

    # log_options {
    #     discard_rule {
    #         http_code_intervals = ["HTTP_2XX"]
    #         discard_percent = 75
    #     }
    # }
}


# yc iam key create --folder-name=practicum-folder --service-account-name practicum-folder-tf-sa --output sa-key.json
# export HELM_EXPERIMENTAL_OCI=1
# cat sa-key.json | helm registry login cr.yandex --username 'json_key' --password-stdin
# helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/yc-alb-ingress/yc-alb-ingress-controller-chart --version v0.1.17 --untar --untardir=charts
# export TF_VAR_IAM_TOKEN=$(yc iam create-token)
# helm install --create-namespace --namespace yc-alb-ingress --set folderId=$(terraform output -json | jq .folder_id.value) --set clusterId=$(terraform output -json | jq .kube_cluster_id.value) --set-file saKeySecretKey=sa-key.json  yc-alb-ingress-controller ./charts/yc-alb-ingress-controller-chart/
# helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/argo/chart/argo-cd --version=4.5.3-1 --untar --untardir=charts











