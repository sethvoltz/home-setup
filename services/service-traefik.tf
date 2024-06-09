resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

resource "kubectl_manifest" "traefik_certificate" {
  depends_on       = [helm_release.cert-manager]
  yaml_body        = <<-END_OF_FILE
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: traefik-${replace(var.base_domain, ".", "-")}
      namespace: traefik
    spec:
      secretName: traefik-${replace(var.base_domain, ".", "-")}-tls
      issuerRef:
        name: letsencrypt
        kind: ClusterIssuer
      commonName: "traefik.${var.base_domain}"
      dnsNames:
      - "traefik.${var.base_domain}"
  END_OF_FILE
}

resource "helm_release" "traefik" {
  namespace  = kubernetes_namespace.traefik.id
  name       = "traefik"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"
  version    = "28.2.0"
  depends_on = [helm_release.cert-manager]

  values = [<<-END_OF_FILE
    globalArguments:
      - "--global.sendanonymoususage=false"
      - "--global.checknewversion=false"

    additionalArguments:
      - "--serversTransport.insecureSkipVerify=true"
      - "--log.level=INFO"

    deployment:
      enabled: true
      replicas: 3
      annotations: {}
      podAnnotations: {}
      additionalContainers: []
      initContainers: []

    ports:
      web:
        port: 80
        redirectTo: websecure
      websecure:
        port: 443
        tls:
          enabled: true
          
    ingressRoute:
      dashboard:
        enabled: false

    providers:
      kubernetesCRD:
        enabled: true
        ingressClass: traefik-external
        allowExternalNameServices: true
      kubernetesIngress:
        enabled: true
        allowExternalNameServices: true
        publishedService:
          enabled: false

    rbac:
      enabled: true

    service:
      enabled: true
      type: LoadBalancer
      annotations: {}
      labels: {}
      spec:
        loadBalancerIP: ${var.traefik_ip} # this should be an IP in the MetalLB range
      loadBalancerSourceRanges: []
      externalIPs: []
  END_OF_FILE
  ]
}

# Build Middleware

resource "kubectl_manifest" "traefik_middleware_default_headers" {
  depends_on       = [helm_release.traefik]
  yaml_body        = <<-END_OF_FILE
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: default-headers
      namespace: default
    spec:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 15552000
        customFrameOptionsValue: SAMEORIGIN
        customRequestHeaders:
          X-Forwarded-Proto: https
  END_OF_FILE
}

resource "kubectl_manifest" "traefik_middleware_basicauth" {
  depends_on       = [helm_release.traefik]
  yaml_body        = <<-END_OF_FILE
    apiVersion: traefik.containo.us/v1alpha1
    kind: Middleware
    metadata:
      name: traefik-dashboard-basicauth
      namespace: traefik
    spec:
      basicAuth:
        secret: traefik-dashboard-auth
  END_OF_FILE
}

resource "kubectl_manifest" "traefik_dashboard_auth" {
  depends_on       = [kubectl_manifest.traefik_middleware_basicauth]
  sensitive_fields = ["data.users"]
  yaml_body        = <<-END_OF_FILE
    apiVersion: v1
    kind: Secret
    metadata:
      name: traefik-dashboard-auth
      namespace: traefik
    type: Opaque
    data:
      users: ${var.dashboard_users}
  END_OF_FILE
}

resource "kubectl_manifest" "traefik_ingress" {
  depends_on       = [kubectl_manifest.traefik_dashboard_auth]
  yaml_body        = <<-END_OF_FILE
    apiVersion: traefik.containo.us/v1alpha1
    kind: IngressRoute
    metadata:
      name: traefik-dashboard
      namespace: traefik
      annotations: 
        kubernetes.io/ingress.class: traefik-external
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(`traefik.${var.base_domain}`)
          kind: Rule
          middlewares:
            - name: traefik-dashboard-basicauth
              namespace: traefik
          services:
            - name: api@internal
              kind: TraefikService
      tls:
        secretName: traefik-${replace(var.base_domain, ".", "-")}-tls
  END_OF_FILE
}
