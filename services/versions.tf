terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    http = {
      source = "hashicorp/http"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }

    rancher2 = {
      source  = "rancher/rancher2"
      version = "4.2.0"
    }
  }
}
