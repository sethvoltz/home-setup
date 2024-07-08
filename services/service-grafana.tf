resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
  }
}

resource "kubernetes_secret" "grafana-creds" {
  metadata {
    name      = "grafana-creds"
    namespace = kubernetes_namespace.grafana.id
  }

  data = {
    user     = "admin"
    password = local.grafana_password
  }
}

resource "helm_release" "grafana" {
  depends_on = [kubernetes_secret.grafana-creds]
  name       = "grafana"
  namespace  = kubernetes_namespace.grafana.id
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "8.3.2"

  values = [<<-EOD
    admin:
      existingSecret: grafana-creds
      userKey: user
      passwordKey: password
    sidecar:
      dashboards:
        enabled: true
        searchNamespace: ALL
    serviceMonitor:
      enabled: true
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Prometheus
          type: prometheus
          url: http://thanos-query-frontend.thanos.svc:9090
        # - name: Loki
        #   type: loki
        #   url: http://loki-read.loki.svc:3100
        #   is_default: true
        # - name: CloudWatch
        #   type: cloudwatch
        #   jsonData:
        #     authType: default
        #     defaultRegion: us-west-2
    plugins:
    - grafana-piechart-panel
    - grafana-clock-panel
    - pr0ps-trackmap-panel
    - natel-discrete-panel
    - grafana-strava-datasource
    - grafana-worldmap-panel
    grafana.ini:
      feature_toggles:
        enable: tempoSearch tempoBackendSearch tempoServiceGraph tempoApmTable
      panels:
        enable_alpha: true
    ingress:
      enabled: true
      annotations:
        "cert-manager.io/cluster-issuer": letsencrypt
      enabled: true
      hosts:
      - grafana.${var.base_domain}
      tls:
      - secretName: grafana-server-tls
        hosts:
        - grafana.${var.base_domain}
  EOD
  ]
}
