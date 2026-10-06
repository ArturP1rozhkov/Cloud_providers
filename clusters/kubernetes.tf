# --- 1. Региональный кластер Managed Service for Kubernetes ---

resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "${var.project_name}-k8s"
  description = "Regional Kubernetes cluster for Netology security homework"
  network_id  = yandex_vpc_network.main.id

  # Сервисные аккаунты из iam.tf
  service_account_id      = yandex_iam_service_account.k8s_cluster_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  # Требование: Шифрование секретов ключом из KMS
  kms_provider {
    key_id = var.kms_key_id
  }

  # Требование: Региональный мастер в трёх подсетях
  master {
    regional {
      region = "ru-central1"

      location {
        zone      = yandex_vpc_subnet.k8s_public_a.zone
        subnet_id = yandex_vpc_subnet.k8s_public_a.id
      }
      location {
        zone      = yandex_vpc_subnet.k8s_public_b.zone
        subnet_id = yandex_vpc_subnet.k8s_public_b.id
      }
      location {
        zone      = yandex_vpc_subnet.k8s_public_d.zone
        subnet_id = yandex_vpc_subnet.k8s_public_d.id
      }
    }

    # Публичный эндпоинт для подключения через kubectl
    public_ip = true

    # Привязка Security Group мастера
    security_group_ids = [yandex_vpc_security_group.k8s_main_sg.id]
  }

  # Зависимости из iam.tf: права должны быть выданы до старта кластера
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_agent,
    yandex_resourcemanager_folder_iam_member.k8s_vpc_public_admin,
    yandex_resourcemanager_folder_iam_member.k8s_node_puller,
    yandex_kms_symmetric_key_iam_binding.k8s_kms_encrypter_decrypter
  ]
}

# --- 2. Группа узлов с автомасштабированием 3 -> 6 ---

resource "yandex_kubernetes_node_group" "k8s_nodes" {
  cluster_id  = yandex_kubernetes_cluster.k8s_cluster.id
  name        = "${var.project_name}-node-group"
  description = "Autoscaling node group (3 to 6 nodes)"

  instance_template {
    platform_id = "standard-v3"

    resources {
      core_fraction = 50
      cores         = 2
      memory        = 4
    }

    boot_disk {
      type = "network-hdd"
      size = 32
    }

    # Сетевой интерфейс узлов: публичный IP (NAT) и привязка к Security Group нод
    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.k8s_public_a.id]
      security_group_ids = [yandex_vpc_security_group.k8s_nodes_sg.id]
    }

    scheduling_policy {
      preemptible = false
    }
  }

  # Требование: Автомасштабирование от 3 до 6 узлов
  scale_policy {
    auto_scale {
      min     = 3
      max     = 6
      initial = 3
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.k8s_public_a.zone
    }
  }
}