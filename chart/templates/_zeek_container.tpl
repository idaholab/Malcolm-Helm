{{/* Shared zeek image */}}
{{- define "malcolm.zeek.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.zeek_container_override | default (printf "%s/zeek:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Zeek liveness (live flavors) */}}
{{- define "malcolm.zeek.liveness.live" -}}
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

{{/* Zeek liveness (pcap-processor) */}}
{{- define "malcolm.zeek.liveness.pcap" -}}
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

{{/* Default custom mount */}}
{{- define "malcolm.zeek.mounts.custom" -}}
- mountPath: "/usr/local/zeek/share/zeek/site/custom/configmap"
  name: zeek-custom-volume
{{- end -}}

{{- define "malcolm.zeek.envFrom" -}}
{{- $root := .root -}}
{{- $mode := .mode | default "offline" -}}
envFrom:
{{- if or (eq $mode "live") (eq $mode "liveRemote") }}
{{- with $root.Values.zeek_live.extra_envFrom }}
{{- if ne (len .) 0 }}
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
  - configMapRef: { name: process-env }
  - configMapRef: { name: ssl-env }
{{- if eq $mode "pcapProcessor" }}
  - configMapRef: { name: upload-pcap-offline-env }
{{- else }}
  - configMapRef: { name: upload-common-env }
{{- end }}
  - configMapRef: { name: zeek-env }

{{- if $root.Values.kafka.enabled }}
  - configMapRef: { name: kafka-config }
{{- end }}

{{- if or (eq $mode "live") (eq $mode "liveRemote") }}
  - configMapRef: { name: zeek-live-env }
  - configMapRef: { name: pcap-capture-env }
{{- else }}
  - configMapRef: { name: zeek-offline-env }
{{- end }}
{{- end -}}

{{/*
Generic zeek container (emits a list item).

Params:
  root: $
  name: string (default zeek-container)
  mode: "offline" | "live" | "liveRemote" | "pcapProcessor"
  securityContext: map (required)
  envFrom: list (required)
  env: list (optional)
  baseVolumeMounts: list (required) # mounts excluding the “custom vs overrides” block
*/}}
{{- define "malcolm.zeek.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "zeek-container" -}}
{{- $mode := .mode | default "offline" -}}
{{- $sc := .securityContext -}}
{{- $env := .env | default (list) -}}
{{- $baseMounts := .baseVolumeMounts | default (list) -}}
- name: {{ $name }}
  image: "{{ include "malcolm.zeek.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $sc | nindent 4 }}
  {{ include "malcolm.zeek.envFrom" (dict "root" $root "mode" $mode) | nindent 2 }}
{{- if gt (len $env) 0 }}
  env:
{{ toYaml $env | nindent 4 }}
{{- end }}

{{- if or (eq $mode "live") (eq $mode "liveRemote") }}
{{ include "malcolm.zeek.liveness.live" . | nindent 2 }}
{{- else if eq $mode "pcapProcessor" }}
{{ include "malcolm.zeek.liveness.pcap" . | nindent 2 }}
{{- end }}
{{/*
  TODO note that for now the "offline" mode has no liveness check, because sometimes it takes a really log time for the container to pull all the misp data
  and I dont want it restarting. We should move this logic to a separate kubernetes job and cronjob.
*/}}

  volumeMounts:
{{ toYaml $baseMounts | nindent 4 }}

{{- /* Append overrides or default custom mount depending on mode */ -}}
{{- if eq $mode "live" }}
{{- if ne (len $root.Values.zeek_chart_overrides.live_volumeMounts) 0 }}
{{ toYaml $root.Values.zeek_chart_overrides.live_volumeMounts | nindent 4 }}
{{- else }}
{{ include "malcolm.zeek.mounts.custom" . | nindent 4 }}
{{- end }}

{{- else if eq $mode "liveRemote" }}
{{- if ne (len $root.Values.zeek_chart_overrides.live_remote_volumeMounts) 0 }}
{{ toYaml $root.Values.zeek_chart_overrides.live_remote_volumeMounts | nindent 4 }}
{{- else }}
{{ include "malcolm.zeek.mounts.custom" . | nindent 4 }}
{{- end }}

{{- else }}
{{- if ne (len $root.Values.zeek_chart_overrides.offline_upload_volumeMounts) 0 }}
{{ toYaml $root.Values.zeek_chart_overrides.offline_upload_volumeMounts | nindent 4 }}
{{- else }}
{{ include "malcolm.zeek.mounts.custom" . | nindent 4 }}
{{- end }}
{{- end }}
{{- end -}}