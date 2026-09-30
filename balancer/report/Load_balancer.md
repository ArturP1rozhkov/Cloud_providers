---
type: Курс по DevOPS Home Work
module: Cloud providers
lesson_no: 2
lesson_theme: Балансировщики нагрузки
---
> [!bookmark]
>
> **Домашнее задание: <%+ tp.file.title %>**

# Домашнее задание к занятию «Вычислительные мощности. Балансировщики нагрузки»
### Подготовка к выполнению задания
Домашнее задание состоит из обязательной части, которую нужно выполнить на провайдере Yandex Cloud, и дополнительной части в AWS (выполняется по желанию). Все домашние задания в блоке 15 связаны друг с другом и в конце представляют пример законченной инфраструктуры. Все задания нужно выполнить с помощью Terraform. Результатом выполненного домашнего задания будет код в репозитории. Перед началом работы настройте доступ к облачным ресурсам из Terraform, используя материалы прошлых лекций и домашних заданий.
## Задание 1. Yandex Cloud
Что нужно сделать:
1. Создать бакет Object Storage и разместить в нём файл с картинкой:
- Создать бакет в Object Storage с произвольным именем (например, имя_студента_дата).
- Положить в бакет файл с картинкой.
- Сделать файл доступным из интернета.
2. Создать группу ВМ в public подсети фиксированного размера с шаблоном LAMP и веб-страницей, содержащей ссылку на картинку из бакета:
- Создать Instance Group с тремя ВМ и шаблоном LAMP. Для LAMP рекомендуется использовать image_id = fd827b91d99psvq5fjit.
- Для создания стартовой веб-страницы рекомендуется использовать раздел user_data в meta_data.
- Разместить в стартовой веб-странице шаблонной ВМ ссылку на картинку из бакета.
- Настроить проверку состояния ВМ.
3. Подключить группу к сетевому балансировщику:
- Создать сетевой балансировщик.
- Проверить работоспособность, удалив одну или несколько ВМ.
4. (дополнительно)* Создать Application Load Balancer с использованием Instance group и проверкой состояния.
#### Полезные документы:
- https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/compute_instance_group
- https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/lb_network_load_balancer
- https://cloud.yandex.ru/docs/compute/operations/instance-groups/create-with-balancer

## Разбор решения задания.
### Ра основании terraform файлов предыдущего задания создал в новой папке набор новых файлов:
#### `storage.tf`
```yaml
resource "yandex_iam_service_account" "storage-sa" {
  name        = "storage-sa"
  description = "Сервисный аккаунт для работы с Object Storage"
}

resource "yandex_resourcemanager_folder_iam_member" "storage-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage-sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage-key" {
  service_account_id = yandex_iam_service_account.storage-sa.id
  description        = "Статический ключ для доступа к Object Storage"
}

resource "yandex_storage_bucket" "lamp" {
  access_key = yandex_iam_service_account_static_access_key.storage-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage-key.secret_key
  bucket     = var.bucket_name

  anonymous_access_flags {
    read = true
  }
}

resource "yandex_storage_object" "picture" {
  access_key  = yandex_iam_service_account_static_access_key.storage-key.access_key
  secret_key  = yandex_iam_service_account_static_access_key.storage-key.secret_key
  bucket      = yandex_storage_bucket.lamp.id
  key         = "lamp.png"
  source      = "${path.module}/files/lamp.png"
  content_type = "image/png"
}
```

- Создал папку  `files` рядом с конфигами и положил в нее картинку (files/lamp.png)
#### `variables.tf`
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
  default = "yc-user"
}

variable "bucket_name" {
  type        = string
  description = "Имя бакета в Object Storage"
}

variable "lamp_image_id" {
  type        = string
  default     = "fd827b91d99psvq5fjit"
  description = "ID образа LAMP из marketplace"
}
```

#### `terraform.tfvars`
```yaml
cloud_id  = "b1g3g3a6ro9rr9hd0mvm"

folder_id = "b1grsjmidldjs2rmkgd0"

bucket_name = "kva-20260930"
```

#### `outputs.tf`
```yaml
output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}

output "load_balancer_public_ip" {
   description = "Публичный IP сетевого балансировщика"
   value = one([
     for listener in yandex_lb_network_load_balancer.lamp.listener :
     one(listener.external_address_spec[*].address)
   ])
 }
```

#### `network.tf`
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
```

#### `instance-group.tf`
```yaml
resource "yandex_iam_service_account" "ig-sa" {
  name        = "ig-sa"
  description = "Сервисный аккаунт для управления группой ВМ"
}

resource "yandex_resourcemanager_folder_iam_member" "ig-editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}

resource "yandex_compute_instance_group" "lamp" {
  name               = "lamp-ig"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.ig-sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.ig-editor
  ]

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.lamp_image_id
        size     = 10
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys  = "${var.ssh_user}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
      user-data = <<-EOF
	   #cloud-config
	   write_files:
		 - path: /var/www/html/index.html
		   permissions: "0644"
		   content: |
			 <!doctype html>
			 <html lang="ru">
			 <head>
			   <meta charset="utf-8">
			   <title>LAMP Instance Group</title>
			 </head>
			 <body>
			   <h1>Homework: Yandex Cloud networking</h1>
			   <p>Страница создана через cloud-init.</p>
			   <img
				 src="https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
				 alt="Картинка из Object Storage"
				 style="max-width: 700px;">
			 </body>
			 </html>
	 EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_creating     = 3
    max_deleting     = 3
    max_expansion    = 3
    max_unavailable  = 1
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name = "lamp-target-group"
  }
}
```

- Создаю отдельный сервисный аккаунт для группы, группу на три ВМ с LAMP, стартовой страницей и проверкой состояния:

#### `loadbalancer.tf`
```yaml
resource "yandex_lb_network_load_balancer" "lamp" {
  name = "lamp-nlb"

  listener {
    name        = "http"
    port        = 80
    target_port = 80
    protocol    = "tcp"
    
    external_address_spec {
	  ip_version = "ipv4"
	}
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http-options {
        port = 80
        path = "/"
      }
    }
  }
}
```
 
- Для сервисного аккаунта группы ВМ были назначена роль editor на уровне каталога. Максимальные привелегии, не для продакшн.
- depends_on на выдачу роли гарантирует, что группа не попытается стартовать раньше, чем роль применится.
- nat = true у интерфейса ВМ. «Публичная подсеть»: каждой ВМ группы выдаётся собственный внешний адрес через one-to-one NAT на интерфейсе, иначе балансировщик не сможет принимать с неё трафик извне. 
- user-data  это cloud-init. LAMP-образ раскладывает стандартную страницу в /var/www/html; write_files перезаписывает index.php своей страницей со ссылкой на картинку при первой загрузке каждой ВМ. Ссылка собирается интерполяцией ${var.bucket_name}, так что при смене имени бакета страница обновится сама. 
- Пользователь в LAMP-образе называется yc-user, поэтому SSH-ключ привязываю к нему.
- Две разные проверки состояния: health_check внутри Instance Group отвечает за то, чтобы упавшая ВМ  пересоздавалась группой, даже если балансировщика нет. 
- health_check внутри attached_target_group балансировщика отвечает за маршрутизацию: упавшая ВМ просто выводится из ротации, но не пересоздаётся. 
- «настроить проверку состояния ВМ» в задании  это групповой уровень. Связка обеих даёт цикл: балансировщик перестал слать трафик - группа заметила по своей проверке и пересоздала ВМ - автоматически вернула в целевую группу. Так устроен официальный мануал  по балансировке, аналогично устроена и группа с автомасштабированием.
- fixed_scale { size = 3 } - требование «фиксированного размера». deploy_policy описан так: без простоев, не больше 1 недоступной ВМ, можно временно поднять 3 дополнительных при обновлениях. Это влияет на поведение при деплое новой версии группы.
- target_group_name в блоке load_balancer группы это задача группе самой создать целевую группу и регистрировать в ней свои ВМ; балансировщик затем подключает её по target_group_id из атрибутов группы. Вручную ВМ в балансировщик добавлять не нужно.
- В файле `loadbalancer.tf` блок listener в схеме провайдера допускает несколько вхождений, и Terraform хранит такие блоки множеством (set). Для извлечения элемента из множества применяю `one(...)` - встроенная функция, которая возвращает единственный элемент из множества/кортежа и не допускает если элементов больше одного.

#### Проверяю и запускаю развертывание инфраструктуры
```bash
terraform fmt
terraform plan
terraform apply
```
export YC_TOKEN=$(yc iam create-token)

#### Проверяю через ссылку в браузере и командой:
```bash
curl -I https://storage.yandexcloud.net/kva-20260930/lamp.png
```


![](<Pasted image 20260930160644.png>)

![](<Pasted image 20260930160951.png>)

- объект lamp.png загружен в бакет;
- бакет разрешает анонимное чтение;
- URL сформирован корректно.

#### список инстансов:
```bash
yc comput instance list
yc load-balancer network-load-balancer get lamp-nlb 
```

![](<Pasted image 20260930161133.png>)

![](<Pasted image 20260930161343.png>)


```bash
yc load-balancer network-load-balancer target-states lamp-nlb \
  --target-group-id enpie9euuum2du8epc9r \
  --format json
```

![](<Pasted image 20260930161517.png>)

#### Внесенные изменения в instance-group.tf 
перезапиcал cloud-init - созданиt стартовой веб-страницы в разделе user_data в meta_data, применил на работающей инфраструктуре и инстансы обновили конфигурацию через rolling update. Созданы новые экземпляры по обновлённому шаблону и удалены прежние согласно deploy_policy. При max_unavailable = 1 сервис сохранял 3 (минимум две по политике) доступные ВМ во время обновления.

![](<Pasted image 20260930202257.png>)


![](<Pasted image 20260930202158.png>)

#### Проверка через балансировщик:
```bash
curl -i "http://$(terraform output -raw load_balancer_public_ip)/"
```

![](<Pasted image 20260930203531.png>)

- ссылка на картинку из бакета
![](<Pasted image 20260930204035.png>)

#### Проверка подключенных к балансировщику ВМ:
```bash
yc load-balancer network-load-balancer target-states lamp-nlb \
  --target-group-id enpldhtgkv01hhs7cul4 \
  --format json
```

![](<Pasted image 20260930204119.png>)

#### Проверка работоспособности при удалении ВМ:
```bash
yc compute instance list
yc compute instance delete fhmcqfdqnehfh2li8jht
curl -s -o /dev/null -w "%{http_code}\n" \                      # во время удаления
  "http://$(terraform output -raw load_balancer_public_ip)/"
```

![](<Pasted image 20260930204555.png>)

- машина пересоздается

![](<Pasted image 20260930204614.png>)

- сервис доступен
![](<Pasted image 20260930204711.png>)

- машина пересоздалась автоматически. Задание выполнено.

## Разбор решения задания *
4. (дополнительно)* Создать Application Load Balancer с использованием Instance group и проверкой состояния.

### План:
- заменю интеграцию Instance Group с NLB на ALB;
- добавлю сетевые компоненты;
- NLB и созданная им target group будут удалены; 
- группа ВМ продолжит существовать, но получит новую ALB target group. 
- группе нужны роли `compute.editor` и `alb.editor`;
- миграция в 2 шага. Необходимы зависимости Instance Group -> ALB target group -> backend group -> router -> ALB. Terraform не сможет создать backend group, пока Instance Group ещё не вернула ID новой ALB target group.
- Шаг 1: убрать NLB, переключить текущую группу на ALB target group и назначить alb.editor;
- Шаг 2: создать backend group, HTTP router и Application Load Balancer.

#### Изменения в instance-group.tf
```yaml
resource "yandex_iam_service_account" "ig-sa" {
  name        = "ig-sa"
  description = "Сервисный аккаунт для управления группой ВМ"
}

resource "yandex_resourcemanager_folder_iam_member" "ig-editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "ig-alb-editor" {
  folder_id = var.folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}

resource "yandex_compute_instance_group" "lamp" {
  name               = "lamp-ig"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.ig-sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.ig-editor,
    yandex_resourcemanager_folder_iam_member.ig-alb-editor
  ]

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.lamp_image_id
        size     = 10
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys  = "${var.ssh_user}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
      user-data = <<-EOF
        #cloud-config
        write_files:
          - path: /var/www/html/index.html
            permissions: "0644"
            content: |
              <!doctype html>
              <html lang="ru">
              <head>
                <meta charset="utf-8">
                <title>LAMP Instance Group</title>
              </head>
              <body>
                <h1>Homework: Yandex Cloud networking</h1>
                <p>Страница создана через cloud-init.</p>
                <img
                  src="https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
                  alt="Картинка из Object Storage"
                  style="max-width: 700px;">
              </body>
              </html>
      EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_creating    = 3
    max_deleting    = 3
    max_expansion   = 3
    max_unavailable = 1
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    http_options {
      port = 80
      path = "/"
    }
  }

  application_load_balancer {
    target_group_name        = "lamp-alb-target-group"
    target_group_description = "Target group for LAMP Instance Group and ALB"
}
}
```

- добавил блок в ресурсы:
```yaml
resource "yandex_resourcemanager_folder_iam_member" "ig-alb-editor" {
  folder_id = var.folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}
```
- Заменил блок интеграции группы
```yaml
application_load_balancer {
  target_group_name        = "lamp-alb-target-group"
  target_group_description = "Target group for LAMP Instance Group and ALB"
}
```
- Обновил блок depends 
```yaml
depends_on = [
  yandex_resourcemanager_folder_iam_member.ig-editor,
  yandex_resourcemanager_folder_iam_member.ig-alb-editor
]
```
#### В outputs.tf закоментил все кроме блока
```yaml
output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}
```

#### Применил
```bash
terraform fmt
terraform validate
terraform plan
```

![](<Pasted image 20260930212640.png>)

План соответствует миграции, это полное пересоздание Instance Group. Провайдер пометил смену типа интеграции load_balancer на application_load_balancer как # forces replacement. NLB и ALB используют разные виды target group, а новая ALB target group будет создана вместе с новой группой. Но Terraform может попытаться удалить Instance Group до удаления NLB, а Yandex Cloud не даёт удалить группу, если её target group ещё подключена к балансировщику. 
Поэтому удаление ресурсов сделаю в таком порядке:
```bash
terraform destroy -target=yandex_lb_network_load_balancer.lamp # Plan: 0 to add, 0 to change, 1 to destroy. Далее 
terraform plan
terraform apply
```

#### После успешного удаления 2 ресурсов и создания 2 новых, создал файл alb.tf
```yaml
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

  allocation_location {
    zone_id   = var.zone
    subnet_id = yandex_vpc_subnet.public.id
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
```

- backend_group направляет HTTP к ВМ из ALB target group на порт 80;
- healthcheck проверяет GET / раз в 2 секунды и ожидает успешный HTTP-ответ; backend считается доступным после двух успешных проверок подряд;
- http_router и virtual_host направляют все HTTP-запросы (/ по умолчанию) в backend group;
- ALB получает внешний IPv4 и слушает TCP/80. yandex_alb_virtual_host использует router и route, а http_route_action ссылается на backend group, как в официальной схеме Terraform.
#### В outputs.tf добавил:
```yaml
output "application_load_balancer_public_ip" {
  description = "Публичный IP Application Load Balancer"
  value = one(flatten([
     for listener in yandex_alb_load_balancer.lamp.listener :
     listener.endpoint[*].address[*].external_ipv4_address[*].address
   ]))
 }
```

- listener, endpoint и address представлены вложенными множествами/коллекциями, поэтому адрес извлекаем через for и one(), а не через индекс `[0]`.

#### Применил
```bash
terraform fmt
terraform plan
terraform apply
```

![](<Pasted image 20260930220059.png>)

#### Проверил
```bash
curl -i "http://$(terraform output -raw application_load_balancer_public_ip)/"
```

![](<Pasted image 20260930220349.png>)

- 200 OK и заголовок server: ycalb подтверждают, что запрос прошёл через Application Load Balancer, а не напрямую через Apache. ALB уровня L7 принял HTTP-запрос, обработал его через HTTP Router и направил в backend group с ВМ Instance Group.

#### Через консоль:

![](<Pasted image 20260930221625.png>)

#### Через YC CLI:

```bash
yc application-load-balancer load-balancer target-states \
            --id ds7l18ublsa3qgrdv1uo \
            --backend-group-id ds7hk9n56iv4ju0urkgc \
            --format json
```

![](<Pasted image 20260930222127.png>)

#### Через браузер http://51.250.43.231/

![](<Pasted image 20260930220535.png>)
Все работает как задумано. Задание выполнено.

> [!calendar] Дата
> **Добавлено:** 2026-09-30  11:12
> **Изменено: **<%+ tp.file.last_modified_date("YYYY-MM-DD HH:mm") %>
> **Тема задания:** <%+ tp.file.title %>
