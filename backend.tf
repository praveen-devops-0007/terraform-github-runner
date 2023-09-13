terraform {
  backend "azurerm" {
    resource_group_name   = "ActiveServer_ResourceGroup"
    storage_account_name  = "terrformtestingngi"
    container_name        = "mycontainer"
    key                   = "terraform.tfstate"
  }
}
