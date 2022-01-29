#
# Provider
#
provider "azurerm" {
  version = "~> 2.0"
  features {}
}

#
# Variables username and login
#
variable "adminuser" {
  type    = string
  default = "rollwagen"
}

resource "random_password" "password" {
  length      = 16
  special     = true
  min_upper   = 1
  min_numeric = 1
}

#
# Variables
#
variable "location" {
  type    = string
  default = "West Europe"
}

variable "resource_group_name" {
  type    = string
  default = "rg-windows2016vm"
}

#
# export TF_VAR_source_address_prefix=`curl 'https://api.ipify.org?format=text'`
# export TF_VAR_source_address_prefix=`netstat --protocol ip --numeric | grep 22 | grep ESTABLISHED | awk '{print $5}' | awk -F: '{print $1}'`
# export TF_VAR_source_address_prefix=`echo $SSH_CLIENT | awk '{print $1}'`
#
variable "source_address_prefix" {
  type    = string
  default = "*"
}


#
# Resources
# 
resource "azurerm_resource_group" "rg" {
  #ts:skip=accurics.azure.NS.272 "Temporary/ad-hoc playground VM, no resource lock needed."
  name     = var.resource_group_name
  location = var.location
  tags = {
    yor_trace = "fb4f8edb-ea19-49e7-b90a-47ee73504f9f"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    yor_trace = "73ef2c0b-79f3-4ba9-a92f-292f0640573f"
  }
}

resource "azurerm_subnet" "subnet" {
  #ts:skip=accurics.azure.NS.161 "Ensure subnet has NSG: seems false postitive b/c nsg get configure in tf file."
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}



resource "azurerm_public_ip" "pip" {
  name                = "public_ip_windows2016_vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  tags = {
    yor_trace = "fcf9b69c-3be3-4e8c-bf7b-c202479f642f"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-windows2016vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    yor_trace = "a835c51e-48e3-4160-9db9-4aded1ba2433"
  }
}
resource "azurerm_network_security_rule" "nsr" {
  name                        = "allow_remote_rdp_inbound"
  resource_group_name         = azurerm_resource_group.rg.name
  description                 = "Allow remote protocol RDP (3389) inbound."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = 3389
  source_address_prefix       = var.source_address_prefix
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
  tags = {
    yor_trace = "de87273d-04d2-41d2-80b5-65bebfce7330"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_to_nic" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "windows2016vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = var.adminuser
  admin_password      = random_password.password.result
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  tags = {
    yor_trace = "c8677a92-fa14-43d9-9f8d-3c836d9aeca5"
  }
}


#
# Outputs
#
output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}
output "password" {
  value = random_password.password.result
}
