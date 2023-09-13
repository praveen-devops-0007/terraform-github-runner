terraform {
  backend "azurerm" {
    resource_group_name   = "ActiveServer_ResourceGroup"
    storage_account_name  = "terrformtestingngi"
    container_name        = "mycontainer"
    key                   = "terraform.tfstate"
    access_key            = "NVTz67RhIcO7iHsu9rCCjHn3mPZiaYIc0RsaXrA7OMiv4EYAs4m5NQ79JcbTiF/bq43GPnBlthOp+AStqGihsA=="
  }
}
