output "app_service_host" {
  value = "https://${azurerm_linux_web_app.service.default_hostname}"
}

output "dbadmin_password" {
  sensitive = true
  value = random_password.dbadmin.result
}