

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.61.0"
    }
  }
  # need to provide the below values or use the local version of storing tfstate file !
    backend "azurerm" {
    resource_group_name   = "xxx"
    storage_account_name  = "xxx"
    container_name        = "xxx"
    key                   = "xxx.tfstate"
    }

}

provider "azurerm" {
  features {}
}

/*
provider "azurerm"  {
  #subscription_id = local.digit-prod.subscription_id
  subscription_id = "edbdfe7a-4cab-47d3-ac1e-6735c6ec2d1b"
  features  {}
}
*/

resource "azurerm_resource_group" "rg" {
  name     = "rg-aks-workshop-kozammic"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name       = "aks-mmk-k8s"
  location   = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix = "aks-mmk-k8s"

  default_node_pool {
    name       = "prod"
    node_count = "1"
    vm_size    = "Standard_d2_v3"

  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "prod" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  name                  = "prod"
  node_count            = "1"
  vm_size               = "standard_d2_v3"
  enable_auto_scaling = true
  min_count = "2"
  max_count = "4"

}
# Create Virtual Network
resource "azurerm_virtual_network" "aksvnet" {
  name                = "rg-aks-workshop-kozammic-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.224.0.0/12"]
}

# Create a Subnet for AKS
resource "azurerm_subnet" "aks-spoke1" {
  name                 = "spoke1-subnet"
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  resource_group_name = azurerm_resource_group.rg.name
  address_prefixes     = ["10.224.0.0/16"]
}
# background subnet
resource "azurerm_subnet" "aks-backend" {
  name                 = "backend-subnet"
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  resource_group_name = azurerm_resource_group.rg.name
  address_prefixes     = ["10.225.0.0/24"]
}
# nsg group 1
resource "azurerm_network_security_group" "nsg-for-spoke1" {
  name                = "NSGforSpoke1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# nsg group 2
resource "azurerm_network_security_group" "nsg-for-backend" {
  name                = "NSGforBackend"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# nsg 2 association with network subnet
resource "azurerm_subnet_network_security_group_association" "asnsg-for-backend" {
  subnet_id                 = azurerm_subnet.aks-backend.id
  network_security_group_id = azurerm_network_security_group.nsg-for-backend.id
}
# nsg 1 association with network subnet
resource "azurerm_subnet_network_security_group_association" "asnsg-for-spoke1" {
  subnet_id                 = azurerm_subnet.aks-spoke1.id
  network_security_group_id = azurerm_network_security_group.nsg-for-spoke1.id
}