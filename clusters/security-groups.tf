# --- 1. Группа безопасности для Kubernetes (Master и общая связь) ---

resource "yandex_vpc_security_group" "k8s_main_sg" {
  name        = "${var.project_name}-k8s-main-sg"
  description = "Security group for Kubernetes master and internal cluster traffic"
  network_id  = yandex_vpc_network.main.id

  # Проверки доступности от балансировщика Yandex Cloud для regional master
  ingress {
    protocol          = "TCP"
    description       = "Health checks from NLB to regional master"
    from_port         = 0
    to_port           = 65535
    predefined_target = "loadbalancer_healthchecks"
  }

  # Служебный трафик внутри группы (мастер <-> ноды)
  ingress {
    protocol          = "ANY"
    description       = "Internal master-to-node and node-to-node communication"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  # Подключение к API Kubernetes через kubectl (публичный эндпоинт)
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API access from internet"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API access alternative port"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Диагностика ping (ICMP) из подсетей кластера
  ingress {
    protocol       = "ICMP"
    description    = "ICMP for debugging"
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  # Исходящий служебный трафик внутри группы
  egress {
    protocol          = "ANY"
    description       = "Outgoing service traffic within cluster"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  # Разрешаем мастеру исходящий трафик в облако и интернет
  egress {
    protocol       = "ANY"
    description    = "Outgoing traffic for master control plane"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 2. Группа безопасности для Worker-нод Kubernetes и публичных сервисов ---

resource "yandex_vpc_security_group" "k8s_nodes_sg" {
  name        = "${var.project_name}-k8s-nodes-sg"
  description = "Security group for Kubernetes worker nodes and LoadBalancer services"
  network_id  = yandex_vpc_network.main.id

  # Healthchecks от сетевого балансировщика Yandex Cloud
  ingress {
    protocol          = "TCP"
    description       = "Allow healthchecks from Yandex Network Load Balancer"
    from_port         = 0
    to_port           = 65535
    predefined_target = "loadbalancer_healthchecks"
  }

  # Трафик от балансировщика к NodePort пода (для Service type LoadBalancer)
  ingress {
    protocol       = "TCP"
    description    = "Incoming traffic to NodePorts for exposed services"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Внутренний обмен между pod-to-pod
  ingress {
    protocol       = "ANY"
    description    = "Pod-to-pod and service communication within k8s subnets"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
  }

  # Исходящий доступ в интернет (скачивание образов phpMyAdmin, пакетов, обращение к внешним реестрам)
  egress {
    protocol       = "ANY"
    description    = "Allow internet access for pulling container images"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. Группа безопасности для кластера MySQL ---

resource "yandex_vpc_security_group" "mysql_sg" {
  name        = "${var.project_name}-mysql-sg"
  description = "Security group for MySQL cluster allowing traffic only from K8s worker nodes"
  network_id  = yandex_vpc_network.main.id

  # Разрешаем MySQL порт 3306 ТОЛЬКО с нод k8s
  ingress {
    protocol          = "TCP"
    description       = "MySQL access allowed exclusively from Kubernetes node security group"
    port              = 3306
    security_group_id = yandex_vpc_security_group.k8s_nodes_sg.id
  }

  # Исходящий трафик для репликации между хостами внутри группы
  egress {
    protocol          = "ANY"
    description       = "Allow inter-host replication traffic"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}