data "aws_secretsmanager_secret_version" "minio_creds" {
  secret_id = "minio-creds"
}

data "aws_secretsmanager_secret_version" "rancher_creds" {
  secret_id = "rancher-creds"
}

data "aws_secretsmanager_secret_version" "grafana_creds" {
  secret_id = "grafana-creds"
}

data "aws_secretsmanager_secret_version" "alertmanager_slack_url" {
  secret_id = "alertmanager-slack-url"
}

locals {
  minio_creds = jsondecode(
    data.aws_secretsmanager_secret_version.minio_creds.secret_string
  )
  rancher_password       = data.aws_secretsmanager_secret_version.rancher_creds.secret_string
  grafana_password       = data.aws_secretsmanager_secret_version.grafana_creds.secret_string
  alertmanager_slack_url = data.aws_secretsmanager_secret_version.alertmanager_slack_url.secret_string
}
