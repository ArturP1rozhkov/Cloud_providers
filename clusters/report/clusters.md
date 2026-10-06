

## Задание 1. Yandex Cloud
1. Настроить с помощью Terraform кластер баз данных MySQL.
- Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно подсеть private в разных зонах, чтобы обеспечить отказоустойчивость.
- Разместить ноды кластера MySQL в разных подсетях.
- Необходимо предусмотреть репликацию с произвольным временем технического обслуживания.
- Использовать окружение Prestable, платформу Intel Broadwell с производительностью 50% CPU и размером диска 20 Гб.
- Задать время начала резервного копирования — 23:59.
- Включить защиту кластера от непреднамеренного удаления.
- Создать БД с именем netology_db, логином и паролем.
1. Настроить с помощью Terraform кластер Kubernetes.
- Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно две подсети public в разных зонах, чтобы обеспечить отказоустойчивость.
- Создать отдельный сервис-аккаунт с необходимыми правами.
- Создать региональный мастер Kubernetes с размещением нод в трёх разных подсетях.
- Добавить возможность шифрования ключом из KMS, созданным в предыдущем домашнем задании.
- Создать группу узлов, состояющую из трёх машин с автомасштабированием до шести.
- Подключиться к кластеру с помощью kubectl.
- *Запустить микросервис phpmyadmin и подключиться к ранее созданной БД.
- *Создать сервис-типы Load Balancer и подключиться к phpmyadmin. Предоставить скриншот с публичным адресом и подключением к БД.

## Разбор решения задания:
### План:

#### Сеть: 
- Для выполнения задания создам отдельную VPC-сеть `netology-security-vpc`. Она не зависит от default-сети Yandex Cloud, что обеспечивает воспроизводимость Terraform-конфигурации, изоляцию учебной инфраструктуры и предсказуемое управление адресным пространством.
- Для регионального Kubernetes master создам три подсети в независимых зонах доступности ru-central1-a, ru-central1-b и ru-central1-d. Третья подсеть добавлена для выполнения требования о размещении регионального master в трёх разных подсетях и повышения отказоустойчивости.
- Адресный план:

| Подсеть               | Зона          | CIDR           | Назначение                          |
| --------------------- | ------------- | -------------- | ----------------------------------- |
| netology-db-private-a | ru-central1-a | 10.10.10.0/24  | Первый хост Managed MySQL           |
| netology-db-private-b | ru-central1-b | 10.10.20.0/24  | Второй хост Managed MySQL / реплика |
| netology-k8s-public-a | ru-central1-a | 10.10.101.0/24 | Региональный master и worker-ноды   |
| netology-k8s-public-b | ru-central1-b | 10.10.102.0/24 | Региональный master и worker-ноды   |
| netology-k8s-public-d | ru-central1-d | 10.10.103.0/24 | Региональный master и worker-ноды   |

- У MySQL не будет прямого доступа из интернета.
- phpMyAdmin получит доступ к MySQL только по FQDN и по TCP 3306.
- Публично будет доступен сервис LoadBalancer для phpMyAdmin.
- Отдельные security groups запретят «всё всем» и явно разрешат: трафик MySQL TCP 3306 только из security group k8s-нод; служебный трафик Kubernetes между master и worker-нодами; health checks балансировщика; NodePort-диапазон, необходимый для Service type LoadBalancer.
- Security groups обеспечивает доступность кластера и опубликованных Kubernetes-сервисов.

#### KMS-ключ 
- Использую созданный на предыдущем задании. В Terraform он будет передан как существующий ресурс:

```yaml
kms_provider {
  key_id = var.kms_key_id
}
```


#### Cервисные аккаунты:

| Сервисный аккаунт | Роль                             | Зачем нужна                                                                                                            |
| ----------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| k8s-cluster-sa    | k8s.clusters.agent               | Базовое управление нодами, подсетями и дисками кластера                                                                |
| k8s-cluster-sa    | vpc.publicAdmin                  | Создание и управление публичным Network Load Balancer для нашего phpMyAdmin                                            |
| k8s-cluster-sa    | kms.keys.encrypterDecrypter      | Ключевое требование: право использовать наш KMS-ключ abjsoe3gsvnfacsdapj6 для конвертного шифрования секретов кластера |
| k8s-node-sa       | container-registry.images.puller | Скачивание контейнерных образов (стандартный минимум для узлов)                                                        |
| k8s_lb_admin      | load-balancer.admin              | Роль для создания и управления сетевыми балансировщиками                                                               |

#### Создам файлы следующего содержания:
- network.tf - VPC и пять подсетей.
- security-groups.tf - отдельные SG для MySQL, master k8s и worker-нод.
- iam.tf - два service account и IAM bindings.
- mysql.tf - кластер MySQL, БД netology_db, пользователь, пароль, backup, replication, deletion protection.
- kubernetes.tf - региональный master, KMS, node group 3–6.
- phpmyadmin.yaml - Deployment и Service типа LoadBalancer.
- outputs.tf - FQDN MySQL, ID кластера, команда подключения kubectl и идентификаторы.
- terraform.tfvars - локальный файл с cloud_id, folder_id, kms_key_id, именем пользователя БД. 
- variables.tf - файл с переменными
- providers.tf - файл с провайдерами
- .env - переменная (пароль БД)

### Создаю файлы:

#### `providers.tf`
```yaml
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.235.0"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}
```

#### `variables.tf`
```yaml
variable "project_name" {
  description = "Имя проекта для префикса ресурсов"
  type        = string
  default     = "netology-security"
}

variable "cloud_id" {
  description = "ID облака Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
}

variable "default_zone" {
  description = "Зона по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "kms_key_id" {
  description = "ID существующего KMS-ключа"
  type        = string
}

variable "db_name" {
  description = "Имя базы данных MySQL"
  type        = string
  default     = "netology_db"
}

variable "db_user" {
  description = "Имя пользователя базы данных MySQL"
  type        = string
  default     = "netology_user"
}

variable "db_password" {
  description = "Пароль пользователя базы данных MySQL"
  type        = string
  sensitive   = true
}
```

#### `terraform.tfvars`
```yaml
cloud_id   = "b1g3g3a6ro9rr9hd0mvm"
folder_id  = "b1grsjmidldjs2rmkgd0"
kms_key_id = "abjsoe3gsvnfacsdapj6"
```

#### `security-groups.tf`
```yaml
# --- 1. Группа безопасности для Kubernetes (Master и общая связь) ---

resource "yandex_vpc_security_group" "k8s_main_sg" {
  name        = "${var.project_name}-k8s-main-sg"
  description = "Security group for Kubernetes master and internal cluster traffic"
  network_id  = yandex_vpc_network.main.id

  # Служебный трафик внутри группы (мастер - ноды)
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

  # Исходящий служебный трафик
  egress {
    protocol          = "ANY"
    description       = "Outgoing service traffic within cluster"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
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

  # Разрешаю MySQL порт 3306 только с нод k8s
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
```

#### `network.tf`
```yaml
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
```

#### `mysql.tf`
```yaml
resource "yandex_mdb_mysql_cluster" "db" {
  name        = "${var.project_name}-mysql"
  description = "High-availability MySQL cluster for Netology security homework"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.main.id
  version     = "8.0"

  # Защита от непреднамеренного удаления
  deletion_protection = true

  # Группа безопасности (доступ только от нод k8s)
  security_group_ids = [yandex_vpc_security_group.mysql_sg.id]

  # Ресурсы: платформа Intel Broadwell, 50% CPU (b1.medium), 20 Гб SSD
  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  # SQL-режим, установленный Managed MySQL по умолчанию. Это исключает неявное изменение параметра Terraform при следующих apply.
  mysql_config = {
    sql_mode = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"

    # Полусинхронная репликация: подтверждать запись только после записи на реплику
    "rpl_semi_sync_master_wait_for_slave_count" = 1
  }

  # Произвольное время технического обслуживания
  maintenance_window {
    type = "ANYTIME"
  }

  # Время начала резервного копирования 23:59 (UTC)
  backup_window_start {
    hours   = 23
    minutes = 59
  }

  # Нода 1 в private-подсети зоны ru-central1-a
  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.db_private_a.id
    assign_public_ip = false
  }

  # Нода 2 (реплика) в private-подсети зоны ru-central1-b
  host {
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.db_private_b.id
    assign_public_ip = false
  }
}

# Создание базы данных netology_db
resource "yandex_mdb_mysql_database" "netology_db" {
  cluster_id = yandex_mdb_mysql_cluster.db.id
  name       = var.db_name
}

# Создание пользователя БД с правами на созданную базу
resource "yandex_mdb_mysql_user" "netology_user" {
  cluster_id = yandex_mdb_mysql_cluster.db.id
  name       = var.db_user
  password   = var.db_password

  permission {
    database_name = yandex_mdb_mysql_database.netology_db.name
    roles         = ["ALL"]
  }

  # Совместимость с веб-клиентами типа phpMyAdmin
  authentication_plugin = "MYSQL_NATIVE_PASSWORD"
}
```

#### `outputs.tf`
```yaml
output "mysql_cluster_id" {
  description = "ID кластера MySQL"
  value       = yandex_mdb_mysql_cluster.db.id
}

output "mysql_database_name" {
  description = "Имя базы данных"
  value       = yandex_mdb_mysql_database.netology_db.name
}

output "mysql_user" {
  description = "Имя пользователя БД"
  value       = yandex_mdb_mysql_user.netology_user.name
}

output "mysql_hosts" {
  description = "FQDN адреса хостов MySQL кластера"
  value       = [for h in yandex_mdb_mysql_cluster.db.host : h.fqdn]
}
```

#### `.env`
```yaml
export TF_VAR_db_password="SuperNetologyPass123!"
```

### Загрузка переменной пароля ДБ в окружение перед запуском
```
source .env # проверка переменной echo $TF_VAR_db_password

export YC_TOKEN=$(yc iam create-token)
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

![](<Pasted image 20261006131939.png>)

![](<Pasted image 20261006131650.png>)

![](<Pasted image 20261006131727.png>)
![](<Pasted image 20261006131744.png>)

![](<Pasted image 20261006131811.png>)

- Первая часть задания выполнена. Кластер MySQL развернут в отказоустойчивой конфигурации из двух хостов в зонах ru-central1-a и ru-central1-b , база netology_db создана, пароль изолирован в .env.
### IAM и Сервисные аккаунты для Kubernetes.

#### `iam.tf`
```yaml
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
```



##### Конфигурация IAM:
- Создал единый сервисный аккаунт `netology-security-k8s-sa`, совмещающий роли Control Plane и узлов кластера (поддерживается платформой Yandex Cloud).
- Права сервисного аккаунта: роли `k8s.clusters.agent`, `vpc.publicAdmin`, `container-registry.images.puller` на каталог).
- Право шифрования/дешифрования (`kms.keys.encrypterDecrypter`) назначено не на весь каталог, а через `yandex_kms_symmetric_key_iam_binding` на конкретный KMS-ключ `abjsoe3gsvnfacsdapj6`, созданный в предыдущем задании .

#### `kubernetes.tf`
```yaml
# --- 1. Региональный кластер Managed Service for Kubernetes ---

resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "${var.project_name}-k8s"
  description = "Regional Kubernetes cluster for Netology security homework"
  network_id  = yandex_vpc_network.main.id

  # Сервисные аккаунты из iam.tf
  service_account_id      = yandex_iam_service_account.k8s_cluster_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  # Шифрование секретов ключом из KMS
  kms_provider {
    key_id = var.kms_key_id
  }

  # Региональный мастер в трёх подсетях
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

# --- 2. Группа узлов с автомасштабированием  ---

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

  # Автомасштабирование от 3 до 6 узлов
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
```

- Региональный мастер Kubernetes размещен в трёх разных зонах (ru-central1-a, ru-central1-b, ru-central1-d).
- Шифрование секретов KMS-ключом `abjsoe3gsvnfacsdapj6`  через блок `kms_provider`.
- Группа узлов с автомасштабированием: начально 3 машины, масштабирование от 3 до 6 (min = 3, max = 6, initial = 3).
- Защита сетевым контуром через `security_group_ids`.


#### `security-group.tf` привел к виду:
```yaml
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

  # Разрешаю MySQL порт 3306 ТОЛЬКО с нод k8s
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
```

- В предыдущем виде автоматический внутренний облачный балансировщик при выполнении healthcheck мастеров Regional-мастер в Yandex Cloud из 3 виртуальных машин с etcd в трех дата-центрах (`etcd_cluster_size: 3`) упирался в отсутствующее правило `loadbalancer_healthchecks` (было только для группы нод `k8s_nodes_sg`). Поэтому возникала ошибка, при которой облачный балансировщик не мог достучаться проверками до `etcd/kube-apiserver`.
- Кроме того, в предыдущем виде `k8s_main_sg` на egress стояло только `predefined_target = "self_security_group"` (то есть исходящий трафик мастеру был запрещен наружу). Добавил ему общее egress-правило.

#### Добавил вывод команды подключения в `outputs.tf`
```yaml
output "k8s_cluster_id" {
  description = "ID кластера Kubernetes"
  value       = yandex_kubernetes_cluster.k8s_cluster.id
}

output "kubectl_connect_command" {
  description = "Команда для настройки подключения через kubectl"
  value       = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.k8s_cluster.name} --external --force"
}
```

#### Применил
```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

![](<Pasted image 20261006152039.png>)

![](<Pasted image 20261006152116.png>)


### Подключение к кластеру через kubectl (привел переменные окружения в нормативное состояние, чтобы не использовать конфиги предыдущих ДЗ)

```bash
yc managed-kubernetes cluster get-credentials netology-security-k8s --external --force
echo 'export KUBECONFIG=/home/vboxuser/.kube/config' >> ~/.bashrc
export KUBECONFIG=/home/vboxuser/.kube/config
```

![](<Pasted image 20261006154918.png>)

### Создал манифест `phpMyAdmin`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpmyadmin
  labels:
    app: phpmyadmin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: phpmyadmin
  template:
    metadata:
      labels:
        app: phpmyadmin
    spec:
      containers:
        - name: phpmyadmin
          image: phpmyadmin/phpmyadmin:latest
          ports:
            - containerPort: 80
              name: http
          env:
            - name: PMA_HOST
              value: "rc1a-n52ksp42754tki0r.mdb.yandexcloud.net"
            - name: PMA_PORT
              value: "3306"
            - name: PMA_ARBITRARY
              value: "1"
          resources:
            limits:
              cpu: "300m"
              memory: "256Mi"
            requests:
              cpu: "100m"
              memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: phpmyadmin-service
  labels:
    app: phpmyadmin
spec:
  # Из задания: создать сервис-тип Load Balancer
  type: LoadBalancer
  selector:
    app: phpmyadmin
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

#### Задеплоил

``` bash
kubectl apply -f k8s/phpmyadmin.yaml
kubectl get pods -l app=phpmyadmin
```
![](<Pasted image 20261006155002.png>)

#### Получение публичного адреса балансировщика

```bash
kubectl get svc phpmyadmin-service -w
```

![](<Pasted image 20261006160349.png>)

#### Подключаюсь в браузере через полученный ip к phpmyadmin, ввожу адрес сервера: rc1a-n52ksp42754tki0r.mdb.yandexcloud.net (FQDN (полное доменное имя) мастера кластера MySQL из outputs)

![](<Pasted image 20261006160153.png>)

![](<Pasted image 20261006160218.png>)

- переменная в манифесте 
  `name: PMA_ARBITRARY`
              `value: "1"`
указывает на то, что в веб интерфейсе при авторизации необходимо ввести FQDN БД

### ИТОГ
1. Архитектура и отказоустойчивость сети (VPC)
- Создана изолированная сеть `netology-security-vpc` с пятью подсетями в трёх зонах доступности (ru-central1-a, ru-central1-b, ru-central1-d).
- База данных вынесена в две частные (private) подсети без публичных IP-адресов.
- Мастер и узлы Kubernetes размещены в трёх публичных подсетях для обеспечения высокой доступности Control Plane .

2. Отказоустойчивый кластер MySQL
- Окружение: `PRESTABLE`, платформа `Intel Broadwell` с гарантированной долей CPU 50% (класс хоста `b1.medium`, 2 vCPU, 4 Гб RAM), диск 20 Гб SSD.
- Отказоустойчивость: два хоста в разных зонах доступности (ru-central1-a и ru-central1-b) с полусинхронной репликацией (`rpl_semi_sync_master_wait_for_slave_count = 1`) и автоматическим failover .
- Безопасность: включена защита от непреднамеренного удаления (`deletion_protection = true`) , время бэкапов задано на 23:59 UTC , окно техобслуживания - `ANYTIME` . Создана БД `netology_db` и пользователь `netology_user` . Доступ к порту 3306 ограничен в `Security Group` только для группы узлов Kubernetes .
- Управление секретами: пароль учётной записи СУБД исключен из файлов репозитория и передаётся через переменную окружения `TF_VAR_db_password` в  .env файле.

1. Кластер `Managed Service for Kubernetes` с шифрованием KMS
- Control Plane: региональный мастер в трёх зонах доступности с публичным эндпоинтом
- Безопасность и KMS: к кластеру подключен провайдер шифрования `kms_provider` с ключом `abjsoe3gsvnfacsdapj6`, созданным в предыдущем ДЗ . Секреты шифруются алгоритмом AES-256.
- Сервисные аккаунты: права выданы по принципу минимальных привилегий (`k8s.clusters.agent`, `load-balancer.admin`, `vpc.publicAdmin`, `container-registry.images.puller` и  `kms.keys.encrypterDecrypter` на  KMS-ключ).
- Масштабирование: группа узлов с политикой `auto_scale` от 3 до 6 машин .

1. Развертывание `phpMyAdmin` и публикация сервиса
- Развернут Deployment с официальным образом `phpmyadmin/phpmyadmin:latest` .
- Сервис опубликован через облачный `Network Load Balancer` (`type: LoadBalancer`) .
- Подключение выполнено через веб-интерфейс в браузере к `FQDN` мастера базы данных `rc1a-n52ksp42754tki0r.mdb.yandexcloud.net`.

### Процедура корректного destroy инфраструктуры:
- Удаляю приложение и сервис Load Balancer из Kubernetes: облачный балансировщик создавался контроллером Kubernetes, а не напрямую Terraform. Если снести кластер раньше, балансировщик зависнет в облаке как «сирота» и будет блокировать удаление подсетей и VPC
```bash
kubectl delete -f k8s/phpmyadmin.yaml
```

- Снимаю защиту от удаления в `mysql.tf` и применяю
```yaml
deletion_protection = true # меняю на false
source .env
terraform apply -auto-approve
```

- Запускаю  `terraform destroy`

