

# Домашнее задание к занятию «Организация сети»

### Задание 1. Yandex Cloud 

**Что нужно сделать**

1. Создать пустую VPC. Выбрать зону.
2. Публичная подсеть.
 - Создать в VPC subnet с названием public, сетью 192.168.10.0/24.
 - Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1.
 - Создать в этой публичной подсети виртуалку с публичным IP, подключиться к ней и убедиться, что есть доступ к интернету.
3. Приватная подсеть.
 - Создать в VPC subnet с названием private, сетью 192.168.20.0/24.
 - Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс.
 - Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее, и убедиться, что есть доступ к интернету.

# Разбор решения задания 1

### В папке `~/Cloud_providers/network` создал terraform файлы: 
#### `providers.tf`
```yaml
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone     
}
```

#### `variables.tf:`
```yaml
variable "cloud_id" {
   type        = string
   description = "ID облака Yandex Cloud"
 }
 
 variable "folder_id" {
   type        = string
   description = "ID каталога, в котором создаются ресурсы"
 }
 
 variable "zone" {
   type        = string
   default     = "ru-central1-a"
   description = "Зона доступности"
 }
 
 variable "ssh_public_key_path" {
   type        = string
   default     = "~/.ssh/id_ed25519.pub"
   description = "Путь к публичному SSH-ключу"
 }

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

```

#### `network.tf`:
```yaml
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
```

#### `instances.tf`
```yaml
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

locals {
  ssh_key = "${var.ssh_user}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
}

resource "yandex_compute_instance" "nat" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
      size     = 10
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    ip_address = "192.168.10.254"
    nat        = true
  }

  metadata = {
    ssh-keys = local.ssh_key
  }
}

resource "yandex_compute_instance" "public" {
  name        = "public-vm"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    ssh-keys = local.ssh_key
  }
}

resource "yandex_compute_instance" "private" {
  name        = "private-vm"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    nat       = false
  }

  metadata = {
    ssh-keys = local.ssh_key
  }
}
```

#### `outputs.tf`:
```yaml
output "public_vm_ip" {
  value = yandex_compute_instance.public.network_interface[0].nat_ip_address
}

output "nat_instance_ip" {
  value = yandex_compute_instance.nat.network_interface[0].nat_ip_address
}

output "private_vm_ip" {
  value = yandex_compute_instance.private.network_interface[0].ip_address
}
```

#### `terraform.tfvars`:
```yaml
# значения переменных под мое облако.
cloud_id  = "b1g3g3a6ro9rr9hd0mvm"

folder_id = "b1grsjmidldjs2rmkgd0"
```
#### `.gitignore:`
```yaml
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
*.tfvars
*.tfvars.json
```

#### Проверяю и поднимаю:
```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

![](<Pasted image 20260929213754.png>)

![](<Pasted image 20260929213816.png>)

![](<Pasted image 20260929214833.png>)

### Проверка условий задания:
#### Прямой выход в интернет с публичной ВМ 
```bash
ssh ubuntu@51.250.4.166
ip route
curl -4 --max-time 10 ifconfig.co
```

![](<Pasted image 20260929214158.png>)


- Внешний адрес совпадает с `public_vm_ip`, (51.250.4.166). E ВМ есть публичный IP, поэтому она выходит в интернет не через NAT-инстанс
#### Выход приватной ВМ через NAT-инстанс.
```bash
ssh -J ubuntu@51.250.4.166 ubuntu@192.168.20.21
ip route
curl -4 --max-time 10 ifconfig.co
```

![](<Pasted image 20260929214641.png>)

- У privat-vm нет публичного ip, поэтому она выходит в интернет как 111.88.243.189 - через NAT-инстанс.


