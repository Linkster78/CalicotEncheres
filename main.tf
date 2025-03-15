data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "network" {
  name                = "vnet-${var.tag}-calicot-cc-15"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet-web" {
  address_prefixes = ["10.0.1.0/24"]
  name                 = "snet-${var.tag}-web-cc-15"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.network.name

  delegation {
    name = "serverFarmDelegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet" "subnet-db" {
  address_prefixes = ["10.0.2.0/24"]
  name                 = "snet-${var.tag}-db-cc-15"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.network.name
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-calicot-${var.tag}-15"
  location            = var.location
  resource_group_name = var.resource_group
  os_type = "Linux"
  sku_name = "S1"
}

resource "azurerm_linux_web_app" "service" {
  name                = "app-calicot-${var.tag}-15"
  location            = var.location
  resource_group_name = var.resource_group
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  site_config {
    always_on = true
  }

  app_settings = {
    ImageUrl = "https://stcalicotprod000.blob.core.windows.net/images/"
  }

  identity {
    type = "SystemAssigned"
  }

  virtual_network_subnet_id = azurerm_subnet.subnet-web.id
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "app-autoscaling-calicot-${var.tag}-15"
  resource_group_name = var.resource_group
  location           = var.location
  target_resource_id = azurerm_service_plan.plan.id

  profile {
    name = "autoscaling"

    capacity {
      minimum = 1
      maximum = 2
      default = 1
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.plan.id
        operator           = "GreaterThan"
        threshold          = 70
        time_aggregation   = "Average"
        statistic          = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.plan.id
        operator           = "LessThan"
        threshold          = 50
        time_aggregation   = "Average"
        statistic          = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT1M"
      }
    }
  }
}

resource "random_password" "dbadmin" {
  length = 16
  special = true
  override_special = "!*%?#-_"
}

# un essai à mettre la bd mssql dans le subnet db...

# resource "azurerm_private_link_service" "db-link" {
#   name                = "sqlsrv-calicot-link-${var.tag}-15"
#   load_balancer_frontend_ip_configuration_ids = []
#   location            = var.location
#   resource_group_name = var.resource_group
#
#   nat_ip_configuration {
#     name      = "sqlsrv-nat-ip-configuration"
#     primary   = true
#     subnet_id = azurerm_subnet.subnet-db.id
#   }
# }

# resource "azurerm_private_endpoint" "db-endpoint" {
#   name                = "sqlsrv-calicot-endpoint-${var.tag}-15"
#   location            = var.location
#   resource_group_name = var.resource_group
#   subnet_id           = azurerm_subnet.subnet-db.id
#
#   private_service_connection {
#     name                 = "sqlsrv-calicot-svc-conn-${var.tag}-15"
#     private_connection_resource_id = azurerm_mssql_server.db-server.id
#     subresource_names = ["sql-server"]
#     is_manual_connection = false
#   }
# }

resource "azurerm_mssql_server" "db-server" {
  name                = "sqlsrv-calicot-${var.tag}-15"
  location            = var.location
  resource_group_name = var.resource_group
  version             = "12.0"

  administrator_login = "dbadmin"
  administrator_login_password = random_password.dbadmin.result
}

resource "azurerm_mssql_database" "db" {
  name      = "sqldb-calicot-${var.tag}-15"
  server_id = azurerm_mssql_server.db-server.id
  sku_name = "Basic"
}

# pour une certaine raison, les access policies n'ont jamais marché
resource "azurerm_key_vault" "vault" {
  name                = "kv-calicot-${var.tag}-15"
  location            = var.location
  resource_group_name = var.resource_group
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Set", "List", "Get"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_linux_web_app.service.identity[0].principal_id
    secret_permissions = ["Get"]
  }
}