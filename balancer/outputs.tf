output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}

output "load_balancer_public_ip" {
  value = one([for l in yandex_lb_network_load_balancer.lamp.listener : one(l.external_address_spec[*].address)])
}