locals {
  location = {
    australiaeast = "aue"
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
  name     = format("rg-%s", local.suffix)
  location = var.location
}
resource "azurerm_service_plan" "appserviceplan" {
  name                = "webapp-asp-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

#  Deploy code from a public GitHub repo
resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id             = azurerm_linux_web_app.webapp.id
  repo_url           = "https://github.com/Azure-Samples/nodejs-docs-hello-world"
  branch             = "master"
  use_manual_integration = true
  use_mercurial      = false
}

# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapp" {
  name                  = "webapp-${random_integer.ri.result}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.appserviceplan.id
  https_only            = true
  site_config { 
    minimum_tls_version = "1.2"
  }
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
  name                = format("ni-%s", local.suffix)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.runners.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "runners" {
  name                            = replace(format("vm-%s", local.suffix), "-", "")
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
}
