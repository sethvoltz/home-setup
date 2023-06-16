alertmanager:
  externalUrl: https://alertmanager.${base_domain}
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt
    enabled: true
    hosts:
    - alertmanager.${base_domain}
    tls:
    - secretName: prometheus-alerts-tls
      hosts:
      - alertmanager.${base_domain}
  persistentVolume:
    storageClass: local-path
  config:
    global:
      resolve_timeout: 1m
      slack_api_url: ${slack_webhook_url}
    receivers:
    - name: "null"
    - name: slack-notifications
      slack_configs:
      - channel: '${alerts_channel_name}'
        send_resolved: true
        icon_url: https://avatars3.githubusercontent.com/u/3380462
        title: |-
          [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }} for {{ .CommonLabels.job }}
          {{- if gt (len .CommonLabels) (len .GroupLabels) -}}
            {{" "}}(
            {{- with .CommonLabels.Remove .GroupLabels.Names }}
              {{- range $index, $label := .SortedPairs -}}
                {{ if $index }}, {{ end }}
                {{- $label.Name }}="{{ $label.Value -}}"
              {{- end }}
            {{- end -}}
            )
          {{- end }}
        text: >-
          {{ range .Alerts -}}
          *Alert:* {{ .Annotations.title }}{{ if .Labels.severity }} - `{{ .Labels.severity }}`{{ end }}

          *Description:* {{ .Annotations.description }}

          *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
    inhibit_rules:
    - equal:
      - namespace
      source_matchers:
      - alertname="InfoInhibitor"
      target_matchers:
      - severity="info"
    route:
      group_by: ['service']
      receiver: slack-notifications
      routes:
      - receiver: "null"
        group_interval: 1m
        repeat_interval: 1m
        matchers:
        - alertname="Watchdog"
      - receiver: "null"
        matchers:
        - alertname="InfoInhibitor"
