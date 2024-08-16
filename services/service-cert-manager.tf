resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  namespace  = kubernetes_namespace.cert-manager.id
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = "v1.15.3"

  set {
    name  = "installCRDs"
    value = true
  }

  values = [<<-END_OF_FILE
    replicaCount: 3
    extraArgs:
      - --dns01-recursive-nameservers=1.1.1.1:53,9.9.9.9:53
      - --dns01-recursive-nameservers-only
    podDnsPolicy: None
    podDnsConfig:
      nameservers:
        - 1.1.1.1
        - 9.9.9.9
  END_OF_FILE
  ]
}

data "aws_route53_zone" "primary" {
  name = var.dns_zone
}

resource "aws_iam_access_key" "letsencrypt-cluster-issuer" {
  user = "k8s"
  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_secret" "letsencrypt-cluster-issuer-secret" {
  depends_on = [helm_release.cert-manager]
  metadata {
    name      = "route53-credentials-secret"
    namespace = kubernetes_namespace.cert-manager.id
  }

  data = {
    "secret-access-key" : aws_iam_access_key.letsencrypt-cluster-issuer.secret
  }
}

resource "kubectl_manifest" "letsencrypt_cluster_issuer" {
  depends_on       = [helm_release.cert-manager]
  sensitive_fields = ["spec.acme.solvers.*.dns01.route53.accessKeyID"]
  yaml_body        = <<-END_OF_FILE
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt
    spec:
      acme:
        email: ${var.acme_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-secret
        solvers:
        - dns01:
            cnameStrategy: None
            route53:
              region: us-east-1
              hostedZoneID: ${data.aws_route53_zone.primary.zone_id}
              accessKeyID: ${aws_iam_access_key.letsencrypt-cluster-issuer.id}
              secretAccessKeySecretRef:
                name: route53-credentials-secret
                key: secret-access-key
  END_OF_FILE
}
