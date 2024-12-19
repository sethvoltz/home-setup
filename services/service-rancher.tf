resource "kubernetes_namespace" "rancher" {
  metadata {
    name = "cattle-system"
  }
}

resource "helm_release" "rancher" {
  depends_on = [helm_release.cert-manager]
  namespace  = kubernetes_namespace.rancher.id
  name       = "rancher"
  chart      = "rancher"
  repository = "https://releases.rancher.com/server-charts/latest"
  version    = "2.10.1"
  wait       = true

  values = [<<-END_OF_FILE
    global:
      cattle:
        psp:
          enabled: false # disable for k8s/k3s >= 1.25

    replicas: 3 # default is 3

    bootstrapPassword: szm97fpslwnw76bvjgh6jb4vpbpphqqcgm276gnx7kvcnpt782w54q

    hostname: rancher.${var.base_domain}

    ingress:
      tls:
        source: secret # literally 'secret'
      extraAnnotations:
        "cert-manager.io/cluster-issuer": letsencrypt
  END_OF_FILE
  ]
}

# Initialize Rancher server
resource "rancher2_bootstrap" "admin" {
  depends_on = [helm_release.rancher]

  provider = rancher2.bootstrap

  initial_password = "szm97fpslwnw76bvjgh6jb4vpbpphqqcgm276gnx7kvcnpt782w54q"
  password  = local.rancher_password
  telemetry = true
}
