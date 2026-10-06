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

output "k8s_cluster_id" {
  description = "ID кластера Kubernetes"
  value       = yandex_kubernetes_cluster.k8s_cluster.id
}

output "kubectl_connect_command" {
  description = "Команда для настройки подключения через kubectl"
  value       = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.k8s_cluster.name} --external --force"
}