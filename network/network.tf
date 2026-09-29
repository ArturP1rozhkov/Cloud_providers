resource "yandex_vpc_network" "homework" {
  name = "network-homework"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.homework.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_route_table" "private" {
  name       = "private-rt"
  network_id = yandex_vpc_network.homework.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface[0].ip_address
  }
}

resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.homework.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}