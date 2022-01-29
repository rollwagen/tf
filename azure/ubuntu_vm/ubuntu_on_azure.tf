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
  type        = string
  default     = "West Europe"
  description = "Location e.g. 'West Europe'"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-ubuntuvm"
  description = "Resource group name"
}

# export TF_VAR_source_address_prefix=`curl 'https://api.ipify.org?format=text'`
variable "source_address_prefix" {
  type        = string
  default     = "*"
  description = "CIDR/IP address to restrict access from"
}

#
# Resources
#
resource "azurerm_resource_group" "rg" {
  #ts:skip=accurics.azure.NS.272 "Temporary/ad-hoc playground VM, no resource lock needed."
  name     = var.resource_group_name
  location = var.location
  tags = {
    yor_trace = "d0b8cf34-705f-48bd-a68e-b230fe8c4beb"
  }
}

resource "azurerm_virtual_network" "vnet" {
  #ts:skip=accurics.azure.NS.161 "Ensure subnet has NSG: seems false postitive b/c nsg get configure in tf file."
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    yor_trace = "e2425077-32e7-43a7-9b2c-f917da3cff1e"
  }
}


resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
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
  tags = {
    yor_trace = "baf647d8-ed5d-406e-a27d-4cbe7f9443f8"
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
  tags = {
    yor_trace = "82cf43e2-3947-489a-a204-5505b30a49bb"
  }
}

resource "azurerm_network_security_group" "nsg-nic" {
  name                = "nsg-ubuntuvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    yor_trace = "fc6071fc-1d9e-431a-918d-50bb8c554a8e"
  }
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
  tags = {
    yor_trace = "14f1a4b7-eeb4-460a-8e90-79867ae4ce86"
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
  tags = {
    yor_trace = "a9246e20-b74e-47ba-8c24-ca7c9ebc68e1"
  }
}


#
# Output
#
output "public_ip_address" {
  value       = azurerm_public_ip.pip.ip_address
  description = "Public IP address of the provisioned VM"
}
