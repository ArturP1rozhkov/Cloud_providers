resource "yandex_iam_service_account" "ig-sa" {
  name        = "ig-sa"
  description = "Сервисный аккаунт для управления группой ВМ"
}

resource "yandex_resourcemanager_folder_iam_member" "ig-editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}

resource "yandex_compute_instance_group" "lamp" {
  name               = "lamp-ig"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.ig-sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.ig-editor
  ]

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.lamp_image_id
        size     = 10
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys  = "${var.ssh_user}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
      user-data = <<-EOF
        #cloud-config
        write_files:
          - path: /var/www/html/index.php
            content: |
              <html>
                <head><title>LAMP Instance Group</title></head>
                <body>
                  <h1>Homework Yandex Cloud networking</h1>
                  <img src="https://storage.yandexcloud.net/${var.bucket_name}/lamp.png" alt="picture from bucket">
                </body>
              </html>
            permissions: '0644'
      EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_creating     = 3
    max_deleting     = 3
    max_expansion    = 3
    max_unavailable  = 1
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name = "lamp-target-group"
  }
}