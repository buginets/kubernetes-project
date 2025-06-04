# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# # Configure the Microsoft Azure Provider
# provider "azurerm" {
# #   resource_provider_registrations = "none" # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
#    features {}
   
provider "azurerm" {
  features {}

  use_msi         = true
  subscription_id = "c3fe1760-2291-4cbe-8c5a-6980e01baccb"
}



# # Create a resource group
# resource "azurerm_resource_group" "example" {
#   name     = "example-resources"
#   location = "West Europe"
# }

# # Create a virtual network within the resource group
# resource "azurerm_virtual_network" "example" {
#   name                = "example-network"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   address_space       = ["10.0.0.0/16"]
# }