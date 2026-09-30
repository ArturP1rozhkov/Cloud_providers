resource "yandex_iam_service_account" "storage-sa" {
  name        = "storage-sa"
  description = "Сервисный аккаунт для работы с Object Storage"
}

resource "yandex_resourcemanager_folder_iam_member" "storage-editor" {
  folder_id = var.folder_id
  role      = "storage.admin"
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

  depends_on = [
    yandex_resourcemanager_folder_iam_member.storage-editor
  ]
}

resource "yandex_storage_object" "picture" {
  access_key   = yandex_iam_service_account_static_access_key.storage-key.access_key
  secret_key   = yandex_iam_service_account_static_access_key.storage-key.secret_key
  bucket       = yandex_storage_bucket.lamp.id
  key          = "lamp.png"
  source       = "${path.module}/files/lamp.png"
  content_type = "image/png"
}