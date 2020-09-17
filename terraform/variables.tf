variable "location" {
  description  = "Set the Azure region. Default: westeurope"
  default      = "westeurope"
}

variable "env" {
  description  = "Set the env type. Default: demo"
  default      = "demo"
}

variable "k8sVersion" {
  description  = "Set the Kubernetes version to deploy."
  default      = "1.17.9"
}

variable "subnet" {
  description  = "Provide an available subnet range in a VNet. Example: 172.16.2.0/23"
}