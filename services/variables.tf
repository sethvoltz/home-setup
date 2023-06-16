variable "kube_config_path" {
  type = string
  description = "Path to the kube config file to use"
  default = "~/.kube/config"
}

variable "kube_context" {
  type = string
  description = "The context to select from kube config"
  default = "config-k3s"
}

variable "aws_config_paths" {
  type = list(string)
  description = "Path to the shared AWS credentials file"
  default = ["~/.aws/credentials"]
}

variable "aws_profile" {
  type = string
  description = "The credential profile to use for accessing AWS"
  default = "default"
}

variable "acme_email" {
  type = string
  description = "Email address to use for Let's Encrypt"
}

variable "dns_zone" {
  type = string
  description = "DNS Zone to use for Let's Encrypt"
}

variable "traefik_ip" {
  type = string
  description = "The IP in MetalLB range to assign to Traefik"
}

variable "base_domain" {
  type = string
  description = "The base domain name to hang everything off of. Must be within dns_zone."
}

variable "dashboard_users" {
  type = string
  description = "Base64 encoded set of users for BASIC auth to the dashboard"
  sensitive = true
}

variable "thanos_endpoint" {
  type = string
  description = "Domain and port for Thanos storage"
}

variable "thanos_bucket_name" {
  type = string
  description = "Bucket name for Thanos storage"
}

variable "alerts_channel_name" {
  type = string
  description = "The name of the Slack channel to publish alerts to"
}

variable "loki_bucket_name" {
  type = string
  description = "Bucket name for Loki storage"
}
