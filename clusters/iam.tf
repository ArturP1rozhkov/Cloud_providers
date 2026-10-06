# --- 1. Сервисный аккаунт для кластера Kubernetes (Control Plane) ---

resource "yandex_iam_service_account" "k8s_cluster_sa" {
  name        = "${var.project_name}-k8s-cluster-sa"
  description = "Service account for Kubernetes master control plane"
}

# Роль агента кластера (управление узлами, балансировщиками, дисками)
resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_agent" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
}

# Роль для выделения публичных IP и управления внешними балансировщиками
resource "yandex_resourcemanager_folder_iam_member" "k8s_vpc_public_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
}

# Прямое назначение роли на KMS-ключ из прошлого ДЗ для шифрования секретов
resource "yandex_kms_symmetric_key_iam_binding" "k8s_kms_encrypter_decrypter" {
  symmetric_key_id = var.kms_key_id
  role             = "kms.keys.encrypterDecrypter"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
  ]
}

# --- 2. Сервисный аккаунт для Worker-нод Kubernetes ---

resource "yandex_iam_service_account" "k8s_node_sa" {
  name        = "${var.project_name}-k8s-node-sa"
  description = "Service account for Kubernetes worker node group"
}

# Право скачивать образы контейнеров
resource "yandex_resourcemanager_folder_iam_member" "k8s_node_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# Роль для создания и управления сетевыми балансировщиками
resource "yandex_resourcemanager_folder_iam_member" "k8s_lb_admin" {
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
}