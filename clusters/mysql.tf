resource "yandex_mdb_mysql_cluster" "db" {
  name        = "${var.project_name}-mysql"
  description = "High-availability MySQL cluster for Netology security homework"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.main.id
  version     = "8.0"

  # Защита от непреднамеренного удаления по требованию задания
  deletion_protection = false

  # Группа безопасности, созданная на шаге 2 (доступ только от нод k8s)
  security_group_ids = [yandex_vpc_security_group.mysql_sg.id]

  # Ресурсы: платформа Intel Broadwell, 50% CPU (b1.medium), 20 Гб SSD
  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  # Явно фиксируем SQL-режим, установленный Managed MySQL по умолчанию.
  # Это исключает неявное изменение параметра Terraform при следующих apply.
  mysql_config = {
    sql_mode = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"

    # Полусинхронная репликация: подтверждать запись только после записи на реплику
    "rpl_semi_sync_master_wait_for_slave_count" = 1
  }

  # Произвольное время технического обслуживания
  maintenance_window {
    type = "ANYTIME"
  }

  # Время начала резервного копирования — 23:59 (UTC)
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