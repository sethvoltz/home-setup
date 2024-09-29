resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret" "prometheus-thanos-objstore-config" {
  metadata {
    namespace = kubernetes_namespace.monitoring.id
    name      = "thanos-objstore-config"
  }

  data = {
    "objstore.yml" = <<-EOD
      config:
        access_key: ${local.minio_creds["access_key"]}
        bucket: ${var.thanos_bucket_name}
        endpoint: ${var.thanos_endpoint}
        region: main
        secret_key: ${local.minio_creds["secret_key"]}
      type: S3
    EOD
  }
}

resource "helm_release" "kube-prometheus-stack" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring.id
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "63.1.0"

  values = [
    templatefile("${path.module}/templates/alertmanager-values.yml.tpl", {
      slack_webhook_url = local.alertmanager_slack_url,
      base_domain = var.base_domain,
      alerts_channel_name = var.alerts_channel_name
    }),
    templatefile("${path.module}/templates/prometheus-values.yml.tpl", {
      base_domain = var.base_domain
    })
  ]
}
