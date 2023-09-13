locals {
  location = {
    eastus2 = "eu2"
  }
  suffix = format("%s-%s-%s",
    local.location[var.location],
    var.environment,
  var.project)

  custom_data = <<EOF
#cloud-config
runcmd:
- [mkdir, '/actions-runner']
- cd /actions-runner
- [curl, -o, 'actions-runner.tar.gz', -L, 'https://github.com/actions/runner/releases/download/v${var.runner_version}/actions-runner-linux-x64-${var.runner_version}.tar.gz']
- [tar, -xzf, 'actions-runner.tar.gz']
- [chmod, -R, 777, '/actions-runner']
- [su, runner-admin, -c, '/actions-runner/config.sh --url https://github.com/${var.github_organisation} --token ${var.runner_token} --runnergroup ${var.runner_group_name}']
- ./svc.sh install
- ./svc.sh start
- [rm, '/actions-runner/actions-runner.tar.gz']
EOF
}

resource "azurerm_resource_group" "this" {
  name     = "etpx-portal-prod-use2"
  location = var.location
}
resource "azurerm_app_service_plan" "etpx-portal-prod-asp-use2" {
  name                = "etpx-portal-prod-asp-use2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "Linux"
  sku {
    tier = "Standard"
    size = "S3"
  }
}

resource "azurerm_app_service" "etpx-portal-prod-webapp-use2" {
  name                  = "etpx-portal-prod-webapp-use2"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  app_service_plan_id   = azurerm_app_service_plan.etpx-portal-prod-asp-use2.id
  https_only            = true
  site_config {
    dotnet_framework_version = "v4.0"
    app_command_line         = "npx docusaurus serve --port 8080 --no-open"
    linux_fx_version         = "NODE|18-lts"
  }
}
resource "azurerm_app_service" "etpx-portal-prod-backend-use2" {
  name                  = "etpx-portal-prod-backend-use2"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  app_service_plan_id   = azurerm_app_service_plan.etpx-portal-prod-asp-use2.id
  https_only            = true
  site_config {
    dotnet_framework_version = "v4.0"
    linux_fx_version         = "NODE|18-lts"

  }
}

resource "random_integer" "ri" {
  min = 1000
  max = 9999
}



resource "azurerm_storage_account" "this" {
  name                     = format("sa%s", replace(local.suffix, "-", ""))
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_virtual_network" "this" {
  name                = format("vn-%s", local.suffix)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  address_space = [var.network_range]
}

resource "azurerm_subnet" "runners" {
  name                 = format("sn-%s", local.suffix)
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [cidrsubnet(var.network_range, 0, 0)]
}

resource "azurerm_network_interface" "this" {
  name                = "etpx-portal-prod-ghr-use2"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.runners.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "runners" {
  name                            = "etpx-portal-prod-ghr-use2"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  size                            = var.runner_size
  admin_username                  = "runner-admin"
  network_interface_ids           = [azurerm_network_interface.this.id]

  admin_ssh_key {
    username   = "runner-admin"
    public_key = tls_private_key.this.public_key_openssh
  }

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
    name = "etpx-portal-prod-ghr-use2"
  }

  source_image_reference {
    publisher = split(":", var.image_urn)[0]
    offer     = split(":", var.image_urn)[1]
    sku       = split(":", var.image_urn)[2]
    version   = split(":", var.image_urn)[3]
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.this.primary_blob_endpoint
  }

  custom_data = base64encode(local.custom_data)
  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "storage_contributor" {
  principal_id   = azurerm_linux_virtual_machine.runners.identity[0].principal_id
  role_definition_name = "Storage Account Contributor"
  scope          = azurerm_storage_account.this.id
}

#keyvault
resource "azurerm_key_vault" "key_vault" {
  name                        = "etpx-portal-prod-kv-use2"
  vault_uri                   = 
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  enabled_for_disk_encryption = false
  tenant_id                   = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
  soft_delete_retention_days  = 90
  enabledForDeployment        = false
  enabledForTemplateDeployment = false
  enableSoftDelete            = true
  enableRbacAuthorization     = false
  tags                        = {
    "SEALZ-BusinessUnit": "Schneider Digital",
    "SEALZ-CostCenter": "1000-US012639",
    "SEALZ-DataClassification": "SE-Restricted"
  }
  sku_name = "standard"
  network_acls = {
    bypass = "AzureServices",
    defaultAction = "Deny"
  }
  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "2d2f8b82-8232-4fc7-a503-e56f1b6bc2a5"

    key_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "GetRotationPolicy",
      "SetRotationPolicy",
      "Rotate"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers"
    ]
  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "3b74c9b2-9cb1-4f65-b9ec-17cba3e3fb7e"

    certificate_permissions = [
      "Get"
    ]
  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "5611562d-d87f-4ebc-92f1-a761f128308f"

    key_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "GetRotationPolicy",
      "SetRotationPolicy",
      "Rotate"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers"
    ]
  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "5510d643-1b18-4475-9ad8-a80296ad275c"

    key_permissions = [
     "Get",
     "List",
     "Update",
     "Create",
     "Import",
     "Delete",
     "Recover",
     "Backup",
     "Restore",
     "GetRotationPolicy",
     "SetRotationPolicy",
     "Rotate"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    certificate_permissions = [
      
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers"
    ]
  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "2645de3f-7470-4da3-a50d-680d60e4ab92"

    secret_permissions = [
      
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "114423ad-adf5-4b8e-91c5-4faf88c0a0fb"

    key_permissions = [
     "Get",
     "List",
     "Update",
     "Create",
     "Import",
     "Delete",
     "Recover",
     "Backup",
     "Restore",
     "GetRotationPolicy",
     "SetRotationPolicy",
     "Rotate"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers"
    ]

  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "748c5253-f681-4323-87db-cb93461dd406"

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "548c094b-c638-45d5-ae9c-70636b546e0f"

    key_permissions = [
     "Get",
     "List",
     "Update",
     "Create",
     "Import",
     "Delete",
     "Recover",
     "Backup",
     "Restore",
     "GetRotationPolicy",
     "SetRotationPolicy",
     "Rotate"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers"
    ]

  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "d4064fe8-753b-44c7-b521-71c4cd15c0f7"

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

  }

  access_policy {
    tenant_id = "6e51e1ad-c54b-4b39-b598-0ffe9ae68fef"
    object_id = "7bd2bc3a-0444-41d2-a9be-bec5994d3abd"

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

  }
}

        

