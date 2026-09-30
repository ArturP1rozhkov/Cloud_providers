output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}

# output "load_balancer_public_ip" {
#   description = "Публичный IP сетевого балансировщика"
#   value = one([
#     for listener in yandex_lb_network_load_balancer.lamp.listener :
#     one(listener.external_address_spec[*].address)
#   ])
# }

output "application_load_balancer_public_ip" {
  description = "Публичный IP Application Load Balancer"
  
  value = one(flatten([
    for listener in yandex_alb_load_balancer.lamp.listener :
    listener.endpoint[*].address[*].external_ipv4_address[*].address
  ]))
}