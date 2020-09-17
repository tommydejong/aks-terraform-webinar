output "public_ip_address" {
    description = "The IP address that will be associated to the Ingress controller"
    value       = azurerm_public_ip.aks-pip.ip_address
}

output "public_ip_address_dns_label" {
    description = "The domain label that will be used for the Ingress controller"
    value       = azurerm_public_ip.aks-pip.domain_name_label
}

output "aks_additional_rg" {
    description = "The resource group the additional AKS resources are created in"
    value       = azurerm_resource_group.aks-rg.name
}