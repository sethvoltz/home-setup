resource "kubernetes_namespace" "thanos" {
  metadata {
    name = "thanos"
  }
}

resource "kubernetes_secret" "thanos-objstore-config" {
  metadata {
    namespace = kubernetes_namespace.thanos.id
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


resource "helm_release" "thanos" {
  depends_on = [kubernetes_secret.thanos-objstore-config]
  name       = "thanos"
  namespace  = kubernetes_namespace.thanos.id
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "thanos"
  version    = "12.6.3"

  values = [<<-EOD
    # image:
    #   repository: thanosio/thanos
    #   tag: "v0.25.2"
    existingObjstoreSecret: thanos-objstore-config
    storegateway:
      enabled: true
      persistence:
        storageClass: local-path
        size: 40Gi
    compactor:
      enabled: true
      persistence:
        size: 10Gi
        storageClass: local-path
    metrics:
      enabled: true
    query:
      dnsDiscovery:
        sidecarsService: po-thanos-discovery
        sidecarsNamespace: monitoring
  EOD
  ]
}
