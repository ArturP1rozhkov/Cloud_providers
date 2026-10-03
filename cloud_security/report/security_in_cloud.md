
## Задание 1. Yandex Cloud
1. С помощью ключа в KMS необходимо зашифровать содержимое бакета:
- создать ключ в KMS;
- с помощью ключа зашифровать содержимое бакета, созданного ранее.
2. (Выполняется не в Terraform)* Создать статический сайт в Object Storage c собственным публичным адресом и сделать доступным по HTTPS:
- создать сертификат;
- создать статическую страницу в Object Storage и применить сертификат HTTPS;
- в качестве результата предоставить скриншот на страницу с сертификатом в заголовке (замочек).
## Разбор решения задания:

### На основании terraform файлов предыдущего задания создаю бакет:
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
  default = "ubuntu"
}

variable "bucket_name" {
  type        = string
  description = "Имя бакета в Object Storage"
}
```

#### `terraform.tfvars`
```yaml
cloud_id  = "b1g3g3a6ro9rr9hd0mvm"

folder_id = "b1grsjmidldjs2rmkgd0"

bucket_name = "kva-20261001"
```

#### `outputs.tf`
```yaml
output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}

output "access_key" {
  value = yandex_iam_service_account_static_access_key.storage-key.access_key
}

output "sa_id" {
  value = yandex_iam_service_account.storage-sa.id
}
```
- добавил в вывод `output "sa_id"` чтобы не искать ее в консоли или через YC
#### Создал бакет;
```bash
export YC_TOKEN=$(yc iam create-token)
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

- В дополнение к роли `storage.editor` нужна будет роль `kms.keys.encrypterDecrypter` на KMS-ключ для storage-sa. Без неё после включения шифрования загрузка и скачивание объектов через этот сервисный аккаунт будут падать с ошибкой доступа,  это требование документации. Ее добавляю после создания ключа, так как binding роли на ключ требует ID самого ключа.
### Создаю ключ в KMS:
```bash
yc kms symmetric-key create \
  --name homework-bucket-key \
  --default-algorithm aes-256 \
  --description "Ключ для шифрования бакета"
```

![](<Pasted image 20261002185204.png>)
#### Проверка после создания:
```bash
yc kms symmetric-key list
```

![](<Pasted image 20261002185228.png>)
- сохранил id ключа: имя, ID, алгоритм, статус Active и дату создания

#### Биндинг роли:
```bash
yc kms symmetric-key list # беру значениее storage-sa, дальше добавил его в outputs

yc kms symmetric-key add-access-binding \
  --id abjsoe3gsvnfacsdapj6 \
  --role kms.keys.encrypterDecrypter \
  --service-account-id ajetmkh84r7cdqcu52d5
  
  yc kms symmetric-key list-access-bindings --id abjsoe3gsvnfacsdapj6 # проверка биндинга
```

![](<Pasted image 20261002190635.png>)

### Включаю шифрование бакета:
#### через консоль:
![](<Pasted image 20261002192137.png>)

- изменение настройки не влияет на уже загруженные объекты. Шифруются только новые загрузки . Файл, загруженный Terraform'ом, остался незашифрованным.

#### или через AWS CLI:
(https://yandex.cloud/ru/docs/tutorials/security/server-side-encryption?utm_referrer=about%3Ablank#aws-cli_3)
```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install
aws --version

aws configure # ввел ключи AWS Access Key ID, AWS Secret Access Key, Default region name [ru-central1]

env | grep -i AWS # вычистил из пееременных окружения старые ключи
sed -i '188d' ~/.bashrc # номер строки был ы выводе команды
unset AWS_ACCESS_KEY_ID

aws s3api put-bucket-encryption \
  --bucket kva-20261001 \
  --endpoint-url=https://storage.yandexcloud.net \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "abjsoe3gsvnfacsdapj6"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'
  
```

- Для работы AWS CLI с бакетом нужен секретный ключ SA. Временно добавляю его в outputs.tf:
```yaml
output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.storage-key.secret_key
  sensitive = true
}

terraform apply -replace="yandex_iam_service_account_static_access_key.storage-key" # смена ключа
```

#### Проверка результата
```bash
aws s3api get-bucket-encryption --bucket kva-20261001 \
  --endpoint-url=https://storage.yandexcloud.net
```

![](<Pasted image 20261002195557.png>)

- шифрование бакета включено, в ответе видно правило с ключом `abjsoe3gsvnfacsdapj6` и алгоритмом `aws:kms`. Но загруженная ранее картинка лежит в бакете не зашифрованная:
```bash
aws s3api head-object --bucket kva-20261001 --key lamp.png \
  --endpoint-url=https://storage.yandexcloud.net
```

![](<Pasted image 20261002195753.png>)

- В ответе сейчас нет поля ServerSideEncryption

#### Перезаливаю объект, чтобы он попал под новое правило:
```bash
terraform apply -replace="yandex_storage_object.picture"
```

- Terraform затер ручные изменения шифрования бакета и пересоздал его опять на незашифрованное. Включаю шифрование бакета в Terraform:
##### файл `storage.tf` блок `resource "yandex_storage_bucket" "lamp" {` исправляю:
```yaml
...
resource "yandex_storage_bucket" "lamp" {
  access_key = yandex_iam_service_account_static_access_key.storage-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage-key.secret_key
  bucket     = var.bucket_name

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.kms_key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  anonymous_access_flags {
    read = true
  }
}
...

```

##### Добавил в файл `variables.tf`:
```yaml
variable "kms_key_id" {
  type        = string
  description = "ID симметричного ключа KMS для шифрования бакета"
}
```

##### В `terraform.tfvars` дописал:
```yaml
kms_key_id = "abjsoe3gsvnfacsdapj6"
```

#### Проверяю:
```bash
aws s3api head-object --bucket kva-20261001 --key lamp.png \
  --endpoint-url=https://storage.yandexcloud.net
  
curl -I https://storage.yandexcloud.net/kva-20261001/lamp.png
```

![](<Pasted image 20261002204200.png>)

![](<Pasted image 20261002204222.png>)
- lamp.png перезагружен с `SSE-KMS`, что подтверждают поля `"ServerSideEncryption": "aws:kms"` и `"SSEKMSKeyId": "abjsoe3gsvnfacsdapj6"` в `head-object`. Настройка шифрования теперь не потеряется при следующем `terraform apply`, потому что она описана в Terraform.
- скриншот с `AccessDenied` ожидаемый результат: браузер делает анонимный GET-запрос к объекту, а доступа к KMS-ключу у анонимного пользователя нет
- `curl` показал `200` так как ключ `-I` означает выполнить только HTTP HEAD, то есть запросить заголовки и метаданные, не скачивая содержимое объекта.
- Браузер,при этом отправил GET; результат: `AccessDenied`. То есть данные защищены как и задумано.
- `curl -sS -D - -o /dev/null \ https://storage.yandexcloud.net/kva-20261001/lamp.png` выводит ответ 403.

## Разбор решения задания 2

 Создать статический сайт в Object Storage c собственным публичным адресом и сделать доступным по HTTPS:
- создать сертификат;
- создать статическую страницу в Object Storage и применить сертификат HTTPS;
- в качестве результата предоставить скриншот на страницу с сертификатом в заголовке (замочек).

#### Буду работать со своим завалявшимся и доступным доменом arturpirozhkov.su
A-запись домена привязана к провайдеру Cloudflare. 

#### Cоздал чистый бакет `yandex-bucket.arturpirozhkov.su` с публичным доступом
![](<Pasted image 20261002230048.png>)

#### В Certificate-manager Yandex Cloude добавляю сертификат от Let's encrypt

![](<Pasted image 20261002233453.png>)


#### Добавляю в дашборде Cloudflare CNAME запись `_acme-challenge.yandex-bucket` target fpq95l8bgq8kacb51dat.cm.yandexcloud.net (значения из sertificate_manager)

![](<Pasted image 20261002231103.png>)

#### Проверяю корректность записи:
```bash
dig +short CNAME _acme-challenge.yandex-bucket.arturpirozhkov.su @1.1.1.1
```
![](<Pasted image 20261002233714.png>)

- Запись создана и видна от DNS провайдеров

![](<Pasted image 20261002235624.png>)

#### Создал 2 файла HTML 
- `index.html`
```html
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Cloud Security — Yandex Object Storage</title>
  <style>
    :root {
      color-scheme: dark;
      font-family: Arial, Helvetica, sans-serif;
    }

    body {
      display: grid;
      min-height: 100vh;
      margin: 0;
      place-items: center;
      background: #101827;
      color: #e5e7eb;
    }

    main {
      width: min(680px, calc(100% - 48px));
      padding: 40px;
      border: 1px solid #334155;
      border-radius: 16px;
      background: #1e293b;
      box-shadow: 0 20px 60px rgb(0 0 0 / 25%);
    }

    h1 {
      margin-top: 0;
      color: #7dd3fc;
    }

    code {
      padding: 3px 6px;
      border-radius: 5px;
      background: #0f172a;
      color: #facc15;
    }

    .ok {
      color: #86efac;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <main>
    <h1>Статический сайт в Yandex Object Storage</h1>

    <p class="ok">✓ Сайт опубликован в Object Storage</p>
    <p class="ok">✓ Доступен по HTTPS</p>
    <p class="ok">✓ Сертификат выпущен через Yandex Certificate Manager</p>

    <p>
      Домен сайта:
      <code>yandex-bucket.arturpirozhkov.su</code>
    </p>

    <p>
      Практическая работа: «Безопасность в облачных провайдерах».
    </p>
  </main>
</body>
</html>
```

- `error.html`
```html
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <title>404 — страница не найдена</title>
</head>
<body>
  <h1>404 — страница не найдена</h1>
  <p><a href="/">Вернуться на главную страницу</a></p>
</body>
</html>
```

#### загрузил их в бакет через консоль

![](<Pasted image 20261003000528.png>)
#### настроил бакет в режим веб-сайт и прописал в настройках главную страницу `index.html` и страницу ошибки `error.html`
![](<Pasted image 20261003000751.png>)

#### По ссылке, предложенной яндексом открывается статика сайта
![](<Pasted image 20261003000944.png>)

#### Привязываю ссылку о яндекса `http://yandex-bucket.arturpirozhkov.su.website.yandexcloud.net` к моему домену на Cloudflare путем создания второй CNAME записи: 

![](<Pasted image 20261003001234.png>)

#### Проверяю:
```dig +short CNAME yandex-bucket.arturpirozhkov.su @1.1.1.1
```
- записи связаны

![](<Pasted image 20261003001439.png>)

#### Из браузера перенаправляет на `http://yandex-bucket.arturpirozhkov.su.website.yandexcloud.net`

#### Настраиваю HTTPS в бакете: настройки-> безопасность-> HTTPS ->Certificate Manager с источником сертификата let's encrypt `yandex-bucket-cert`

![](<Pasted image 20261003002028.png>)

#### Сертификат применился
![](<Pasted image 20261003100855.png>)

#### Проверка из браузера

![](<Pasted image 20261003100954.png>)

![](<Pasted image 20261003101059.png>)

![](<Pasted image 20261003101115.png>)


