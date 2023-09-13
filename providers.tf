provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
    client_id             = "6fcb43b3-8ef3-4175-a675-19072719c787"
    client_secret         = "ofx8Q~NnVj.DjPl3jZZXD8BIsO2sirtWlq9P0bFP"
    tenant_id             = "b4dc3026-2bc8-4d24-aa73-8d9e35e549d4"
    subscription_id       = "cb3e902d-604f-41a5-9297-c0f6a596a9f7"
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.72.0"
    }
  }
}
