resource "yandex_vpc_network" "homework" {
  name = "network-homework"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.homework.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}