output "picture_url" {
  value = "https://storage.yandexcloud.net/${var.bucket_name}/lamp.png"
}

output "access_key" {
  value = yandex_iam_service_account_static_access_key.storage-key.access_key
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.storage-key.secret_key
  sensitive = true
}