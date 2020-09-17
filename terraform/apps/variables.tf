variable "publicIP" {
  type = string
  description = "The public IP address for the ingress controller"
}

variable "dns_label" {
  type = string
  description = "The DNS label name for the ingress controller"
}

variable "aks_rg" {
  type = string
  description = "The resource group the additional AKS resources were deployed in"
}

variable "certmanagerVersion" {
  type = string
  default = "v1.0.1"
  description = "Which version of Cert-Manager to install"
}