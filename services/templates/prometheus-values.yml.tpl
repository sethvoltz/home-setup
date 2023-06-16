fullnameOverride: po
grafana:
  enabled: false
  forceDeployDashboards: true
prometheus:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt
    enabled: true
    hosts:
    - prometheus.${base_domain}
    tls:
    - secretName: prometheus-server-tls
      hosts:
      - prometheus.${base_domain}
  prometheusSpec:
    scrapeInterval: 30s
    evaluationInterval: 30s
    externalUrl: https://prometheus.${base_domain}
    disableCompaction: true
    containers:
    - name: prometheus
      startupProbe:
        # Give prometheus up to 30min to read through the WAL
        failureThreshold: 120
    resources:
      requests:
        cpu: 800m
        memory: 3400Mi
      limits:
        memory: 4Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources:
            requests:
              storage: 50Gi
    thanos:
      objectStorageConfig:
        name: thanos-objstore-config
        key: objstore.yml
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
  thanosService:
    enabled: true
  thanosServiceMonitor:
    enabled: true

kubeApiServer:
  enabled: true
kubeProxy:
  enabled: false
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false

defaultRules:
  rules:
    kubeApiserver: false
    kubeApiserverAvailability: false
    kubeApiserverSlos: false
    kubeSchedulerAlerting: false
    kubeSchedulerRecording: false
