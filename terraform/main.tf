# ======================================================================================================================
# === Terraform version requirements for binary and providers
# ======================================================================================================================

provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  features {}
}

terraform {
  required_version = ">= 0.13.0"
    required_providers {
        azuread   = {
          source  = "hashicorp/azuread"
          version = "1.0.0"
        }
        azurerm   = {
          source  = "hashicorp/azurerm"
          version = "2.26.0"
        }
    }
}    

# ======================================================================================================================
# === Set local script values based on provided variables
# ======================================================================================================================

locals {
  # Set local values
  clustername = "webinar-aks-${var.env}" # Generate the cluster name
  rg          = "${local.clustername}-rg"
  tags = {
      "clustername" = local.clustername
      "costarea"    = "IT"
      "environment" = var.env
  }
  address_prefixes  = ["${var.subnet}"] # Rewrite the subnet to a list
}

# ======================================================================================================================
# === Load the Azure subscription, AKS RG and VNet
# ======================================================================================================================

data "azurerm_subscription" "main" {
  subscription_id = "582089b7-6ffa-47b0-8b9b-65f7c583852b"
}

data "azurerm_virtual_network" "webinar-vnet" {
  name                = "webinar-vnet"
  resource_group_name = "webinar-rg"
}

# ======================================================================================================================
# === Create a resource group and subnet for the cluster
# ======================================================================================================================

resource "azurerm_resource_group" "aks-rg" {
  name     = local.rg
  location = var.location
  tags     = local.tags
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = local.clustername
  resource_group_name  = data.azurerm_virtual_network.webinar-vnet.resource_group_name
  address_prefixes     = local.address_prefixes
  virtual_network_name = data.azurerm_virtual_network.webinar-vnet.name
}

resource "azurerm_public_ip" "aks-pip" {
  name                = "${local.clustername}-pip"
  resource_group_name = azurerm_resource_group.aks-rg.name # Create dependency on this resource by referencing it instead of using local.rg
  location            = azurerm_resource_group.aks-rg.location
  allocation_method   = "Static"
  domain_name_label   = "webinar-aks-demo"
  tags                = local.tags
}

# ======================================================================================================================
# === Create a service principal for the cluster using an example of a module from the Terraform registry
# === https://registry.terraform.io/modules/innovationnorway/service-principal/azurerm/1.0.4
# ======================================================================================================================

module "service_principal" {
  source    = "innovationnorway/service-principal/azuread"
  version   = "3.0.0-alpha.1"
  name      = "${local.clustername}sp"
  role      = "Contributor"
  end_date  = "2299-12-30T23:00:00Z" # password never expires
  scopes    = [data.azurerm_subscription.main.id]
}

# ======================================================================================================================
# === Deploy the ARM template using parameters generated by Terraform
# ======================================================================================================================

resource "azurerm_template_deployment" "aks-template-json" {
  name                = local.clustername
  resource_group_name = azurerm_resource_group.aks-rg.name
  template_body       = file("../arm/aks_template.json")
  deployment_mode     = "Incremental"

  parameters = {
      "clustername"             = local.clustername
      "vnetSubnetID"            = azurerm_subnet.aks-subnet.id
      "location"                = var.location
      "servicePrincipalID"      = module.service_principal.application_id
      "servicePrincipalSecret"  = module.service_principal.client_secret
      "k8sVersion"              = var.k8sVersion
  }
}