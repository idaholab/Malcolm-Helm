{{/* Shared suricata image */}}
{{- define "malcolm.suricata.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.suricata_container_override | default (printf "%s/suricata:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Liveness probes */}}
{{- define "malcolm.suricata.livenessProbe.offline" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 120
  periodSeconds: 30
  timeoutSeconds: 15
  successThreshold: 1
  failureThreshold: 10
{{- end -}}

{{- define "malcolm.suricata.livenessProbe.live" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 600
  periodSeconds: 60
  timeoutSeconds: 30
  successThreshold: 1
  failureThreshold: 3
{{- end -}}

{{/* Common “custom rules/configs” mounts */}}
{{- define "malcolm.suricata.mounts.customRulesAndConfigs" -}}
- mountPath: "/opt/suricata/rules/configmap"
  name: suricata-custom-rules-volume
- mountPath: "/opt/suricata/include-configs/configmap"
  name: suricata-custom-configs-volume
{{- end -}}

{{/*
Generic suricata container (emits a list item).

Params:
  root: $
  name: string (default suricata-container)
  mode: "offline" | "live" | "pcapProcessor"   (controls liveness + which override list to use)
  envFrom: list (required)                     (full envFrom list)
  env: list (optional)
  securityContext: map (required)
  baseVolumeMounts: list (required)            (everything except the rules/config overrides)
*/}}
{{- define "malcolm.suricata.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "suricata-container" -}}
{{- $mode := .mode | default "offline" -}}
{{- $envFrom := .envFrom | default (list) -}}
{{- $env := .env | default (list) -}}
{{- $sc := .securityContext -}}
{{- $baseMounts := .baseVolumeMounts | default (list) -}}

- name: {{ $name }}
  image: "{{ include "malcolm.suricata.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $sc | nindent 4 }}
  envFrom:
{{ toYaml $envFrom | nindent 4 }}
{{- if gt (len $env) 0 }}
  env:
{{ toYaml $env | nindent 4 }}
{{- end }}
{{- if eq $mode "live" }}
{{ include "malcolm.suricata.livenessProbe.live" . | nindent 2 }}
{{- else }}
{{ include "malcolm.suricata.livenessProbe.offline" . | nindent 2 }}
{{- end }}
  volumeMounts:
{{ toYaml $baseMounts | nindent 4 }}
{{- if eq $mode "live" }}
{{- if ne (len $root.Values.suricata_chart_overrides.live_volumeMounts) 0 }}
{{ toYaml $root.Values.suricata_chart_overrides.live_volumeMounts | nindent 4 }}
{{- else }}
{{ include "malcolm.suricata.mounts.customRulesAndConfigs" . | nindent 4 }}
{{- end }}
{{- else }}
{{- if ne (len $root.Values.suricata_chart_overrides.volumeMounts) 0 }}
{{ toYaml $root.Values.suricata_chart_overrides.volumeMounts | nindent 4 }}
{{- else }}
{{ include "malcolm.suricata.mounts.customRulesAndConfigs" . | nindent 4 }}
{{- end }}
{{- end }}
{{- end -}}