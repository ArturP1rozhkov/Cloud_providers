resource "yandex_alb_backend_group" "lamp" {
  name        = "lamp-backend-group"
  description = "Backend group for LAMP Instance Group"

  http_backend {
    name             = "lamp-http-backend"
    port             = 80
    target_group_ids = [yandex_compute_instance_group.lamp.application_load_balancer[0].target_group_id]
    weight           = 1

    load_balancing_config {
      mode            = "ROUND_ROBIN"
      panic_threshold = 0
    }

    healthcheck {
      interval            = "2s"
      timeout             = "1s"
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "lamp" {
  name        = "lamp-http-router"
  description = "HTTP router for LAMP website"
}

resource "yandex_alb_virtual_host" "lamp" {
  name           = "lamp-virtual-host"
  http_router_id = yandex_alb_http_router.lamp.id

  route {
    name = "lamp-route"

    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.lamp.id
        timeout          = "10s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "lamp" {
  name        = "lamp-alb"
  description = "Application Load Balancer for LAMP website"

  network_id = yandex_vpc_network.homework.id

  allocation_policy {
    location {
      zone_id   = var.zone
      subnet_id = yandex_vpc_subnet.public.id
    }
  }

  listener {
    name = "http-listener"

    endpoint {
      address {
        external_ipv4_address {}
      }

      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.lamp.id
      }
    }
  }
}