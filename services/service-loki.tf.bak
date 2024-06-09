resource "kubernetes_namespace" "loki" {
  metadata {
    name = "loki"
  }
}

resource "helm_release" "loki" {
  chart      = "loki"
  name       = "loki"
  namespace  = kubernetes_namespace.loki.id
  repository = "https://grafana.github.io/helm-charts"
  version    = "5.8.0"

  set_sensitive {
    name  = "loki.storage.s3.accessKeyId"
    value = local.minio_creds["access_key"]
  }

  set_sensitive {
    name  = "loki.storage.s3.secretAccessKey"
    value = local.minio_creds["secret_key"]
  }

  values = [<<-EOD
    loki:
      auth_enabled: false
      schemaConfig:
        configs:
        - from: 2023-01-01
          store: boltdb-shipper
          schema: v11
          object_store: s3
          index:
            prefix: loki_index_
            period: 24h
      storage:
        bucketNames:
          admin: ${var.loki_bucket_name}
          chunks: ${var.loki_bucket_name}
          ruler: ${var.loki_bucket_name}
        s3:
          endpoint: ${var.thanos_endpoint}
          s3ForcePathStyle: true
        boltdb_shipper:
          shared_store: s3

      compactor:
        shared_store: s3

    monitoring:
      lokiCanary:
        extraArgs:
          - "-interval=30s"
          - "-pruneinterval=5m"
  EOD
  ]
}

# resource "helm_release" "promtail" {
#   chart      = "promtail"
#   name       = "promtail"
#   namespace  = kubernetes_namespace.loki.id
#   repository = "https://grafana.github.io/helm-charts"
#   version    = "4.2.0"
#
#   values = [<<-EOD
#     serviceMonitor:
#       enabled: true
#     config:
#       lokiAddress: http://loki:3100/loki/api/v1/push
#   EOD
#   ]
# }
