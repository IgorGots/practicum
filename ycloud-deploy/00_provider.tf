terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
#   required_version = ">= 0.13"
}

provider "yandex" {
    token       = "${var.IAM_TOKEN}"
    # folder_id   = local.env["FOLDER_ID"]
    # zone      = "ru-central1-a"
}
