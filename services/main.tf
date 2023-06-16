terraform {
  backend "s3" {
    profile = "synology"
    bucket  = "k3s-state-tf"
    key     = "terraform.tfstate"

    endpoint                    = "https://minio.home.voltzbach.com"
    region                      = "main"
    workspace_key_prefix        = "tf_state"
    skip_credentials_validation = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
