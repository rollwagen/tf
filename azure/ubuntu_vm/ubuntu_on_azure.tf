#
# Provider
#
provider "azurerm" {
  version = "~> 2.0"
  features {}
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
  default = "rg-ubuntuvm"
}

# export TF_VAR_source_address_prefix=`curl 'https://api.ipify.org?format=text'`
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
}

resource "azurerm_virtual_network" "vnet" {
#ts:skip=accurics.azure.NS.161 "Ensure subnet has NSG: seems false postitive b/c nsg get configure in tf file."
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}


resource "azurerm_subnet" "subnet" {
  name                = "subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name= azurerm_virtual_network.vnet.name
  address_prefixes      = ["10.0.2.0/24"]
}
resource "azurerm_network_security_group" "nsg-subnet" { #this should fix accurics.azure.NS.161, but does not
  name                = "nsg-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
    security_rule {
    name                       = "nsr_allow_ssh_inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.source_address_prefix
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "nsg-to-subnet" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg-subnet.id
}


resource "azurerm_public_ip" "pip" {
  name                = "public_ip_ubuntu_vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "nsg-nic" {
  name                = "nsg-ubuntuvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_network_security_rule" "nsr" { 
  name                        = "nsr_allow_remote_ssh_inbound"
  resource_group_name         = azurerm_resource_group.rg.name
  description                 = "Allow remote protocol SSH (22) inbound."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 22
  source_address_prefix       = var.source_address_prefix
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg-nic.name
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
}

resource "azurerm_network_interface_security_group_association" "nsg_to_nic" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg-nic.id
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "ubuntuvm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "rollwagen"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "rollwagen"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}


#
# Output
#
output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}



