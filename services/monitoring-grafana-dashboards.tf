resource "kubernetes_config_map" "grafana-dashboards" {
  for_each = fileset("${path.module}/charts", "*.json")

  metadata {
    name      = "grafana-dashboard-${trimsuffix(each.key, ".json")}"
    namespace = kubernetes_namespace.grafana.id
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "${each.key}" = file("${path.module}/charts/${each.key}")
  }
}
