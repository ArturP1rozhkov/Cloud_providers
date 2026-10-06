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