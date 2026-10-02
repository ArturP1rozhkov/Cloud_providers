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

variable "kms_key_id" {
  type        = string
  description = "ID симметричного ключа KMS для шифрования бакета"
}