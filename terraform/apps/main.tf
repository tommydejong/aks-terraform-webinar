# ======================================================================================================================
# === Terraform version requirements for binary and providers
# ======================================================================================================================

terraform {
  required_version = ">= 0.13.0"
    required_providers {
        helm     =  {
          source = "hashicorp/helm"
          version =  "1.3.0"
        }
        kubernetes = {
          source = "hashicorp/kubernetes"
          version = "1.13.1"
        }
        azurerm = {
          source = "hashicorp/azurerm"
          version = "2.26.0"
        }
    }
}

# Configure AzureRM provider
provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  features {}
}

# ======================================================================================================================
# === Create namespaces for NGINX Ingress Controller and Cert Manager
# ======================================================================================================================

# NGINX Ingress namespace
resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
    annotations = {
    }
    labels = {
    }
  }
}

# Cert Manager namespace
resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
    annotations = {
    }
    labels = {
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

# ======================================================================================================================
# === Install NGINX Ingress Controller using helm
# ======================================================================================================================

# Easy solution for adding public Helm repositories. Reference: https://github.com/hashicorp/terraform-provider-helm/issues/163
resource "null_resource" "helm-repo-ingress-nginx" {
  provisioner "local-exec" {
    command = "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
  }
}

# Uses static IP. Reference: https://docs.microsoft.com/en-us/azure/aks/static-ip
resource "helm_release" "nginx-ingress" {
  depends_on = [kubernetes_namespace.nginx-ingress] # Cannot be created if namespace doesn't exist yet

  name       = "nginx-ingress"
  chart      = "ingress-nginx/ingress-nginx"
  namespace  = "nginx-ingress"

  set {
    name  = "controller.service.loadBalancerIP"
    value = var.publicIP
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = var.dns_label
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.aks_rg
  }
}  

# ======================================================================================================================
# === Install cert-manager using helm
# ======================================================================================================================

# Easy solution for adding public Helm repositories. Reference: https://github.com/hashicorp/terraform-provider-helm/issues/163
resource "null_resource" "helm-repo-cert-manager" {
  provisioner "local-exec" {
    command = "helm repo add jetstack https://charts.jetstack.io"
  }
}

# Use Helm to install cert-manager release using predefined values
resource "helm_release" "cert-manager" {
  depends_on = [kubernetes_namespace.cert-manager] # Cannot be created if namespace doesn't exist yet

  name       = "cert-manager"
  chart      = "jetstack/cert-manager"
  version    = var.certmanagerVersion
  namespace  = "cert-manager"
  
  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Deploy ClusterIssuer for Cert Manager
resource "null_resource" "cert-manager-clusterissuer" {
  depends_on = [helm_release.cert-manager] # Uses custom resource definitions installed as part of the Helm chart

  provisioner "local-exec" {
    command = "kubectl apply -f manifests/cluster-issuer.yaml"
  }
}

# ======================================================================================================================
# === Deploy hello world application
# ======================================================================================================================

resource "null_resource" "aks-helloworld" {
  depends_on = [helm_release.nginx-ingress] # Wait for nginx ingress to fully initialize the load balancer before deploying

  provisioner "local-exec" {
    command = "kubectl apply -f manifests/aks-helloworld.yaml"
  }
}