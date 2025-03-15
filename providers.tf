terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.19.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }

  backend "azurerm" {
    subscription_id = "34c6c373-ad28-45b2-a866-de1d853f2812"
    resource_group_name  = "rg-calicot-web-dev-15"
    storage_account_name = "team15storage"
    container_name       = "tfstate"
    key                  = "detfstate"
  }
}

provider "azurerm" {
  subscription_id = "34c6c373-ad28-45b2-a866-de1d853f2812"
  client_id = "3129e50b-7b2b-4004-a2a8-678b02d1d89e"
  tenant_id = "4dbda3f1-592e-4847-a01c-1671d0cc077f"
  features {}
}
