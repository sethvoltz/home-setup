provider "helm" {
  kubernetes {
    config_path    = var.kube_config_path
    config_context = var.kube_context
  }
}

provider "kubernetes" {
  config_path    = var.kube_config_path
  config_context = var.kube_context
}

provider "kubectl" {
  config_path    = var.kube_config_path
  config_context = var.kube_context
}

provider "aws" {
  shared_credentials_files = var.aws_config_paths
  profile                  = var.aws_profile
}

provider "rancher2" {
  alias = "bootstrap"

  api_url   = "https://rancher.${var.base_domain}"
  bootstrap = true
}
