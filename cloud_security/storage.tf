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

resource "yandex_storage_object" "picture" {
  access_key   = yandex_iam_service_account_static_access_key.storage-key.access_key
  secret_key   = yandex_iam_service_account_static_access_key.storage-key.secret_key
  bucket       = yandex_storage_bucket.lamp.id
  key          = "lamp.png"
  source       = "${path.module}/files/lamp.png"
  content_type = "image/png"
}