# Изолированная облачная сеть
resource "yandex_vpc_network" "main" {
  name        = "${var.project_name}-vpc"
  description = "VPC network for Netology cloud security homework"
}

# --- Подсети для кластера MySQL (Private) ---

resource "yandex_vpc_subnet" "db_private_a" {
  name           = "${var.project_name}-db-private-a"
  description    = "Private subnet for MySQL host 1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.10.0/24"]
}

resource "yandex_vpc_subnet" "db_private_b" {
  name           = "${var.project_name}-db-private-b"
  description    = "Private subnet for MySQL host 2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.20.0/24"]
}

# --- Подсети для регионального кластера Kubernetes (Public) ---

resource "yandex_vpc_subnet" "k8s_public_a" {
  name           = "${var.project_name}-k8s-public-a"
  description    = "Public subnet for Kubernetes master & nodes in zone A"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.101.0/24"]
}

resource "yandex_vpc_subnet" "k8s_public_b" {
  name           = "${var.project_name}-k8s-public-b"
  description    = "Public subnet for Kubernetes master & nodes in zone B"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.102.0/24"]
}

resource "yandex_vpc_subnet" "k8s_public_d" {
  name           = "${var.project_name}-k8s-public-d"
  description    = "Public subnet for Kubernetes master & nodes in zone D"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.103.0/24"]
}