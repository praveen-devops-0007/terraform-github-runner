terraform {
  backend "azurerm" {
    resource_group_name   = "ActiveServer_ResourceGroup"
    storage_account_name  = "terrformtestingngi"
    container_name        = "mycontainer"
    key                   = "terraform.tfstate"
    client_id             = "6fcb43b3-8ef3-4175-a675-19072719c787"
    client_secret         = "ofx8Q~NnVj.DjPl3jZZXD8BIsO2sirtWlq9P0bFP"
    tenant_id             = "b4dc3026-2bc8-4d24-aa73-8d9e35e549d4"
    subscription_id       = "cb3e902d-604f-41a5-9297-c0f6a596a9f7"

  }
}
