{{/* Shared pcap-monitor image */}}
{{- define "malcolm.pcapMonitor.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.pcap_monitor_container_override | default (printf "%s/pcap-monitor:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared livenessProbe */}}
{{- define "malcolm.pcapMonitor.livenessProbe" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 90
  periodSeconds: 30
  timeoutSeconds: 15
  successThreshold: 1
  failureThreshold: 10
{{- end -}}

{{/*
Generic pcap-monitor container (emits a list item).

Params:
  root: $
  name: string (default pcap-monitor-container)
  mode: "monitor" | "processor"
  env: list (required)
  pcapVolumeName: string (required)
  zeekVolumeName: string (required)
  curlrcVolumeName: string (optional; only for mode=monitor)
*/}}
{{- define "malcolm.pcapMonitor.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "pcap-monitor-container" -}}
{{- $mode := .mode | default "monitor" -}}
{{- $env := .env | default (list) -}}
{{- $pcapVol := .pcapVolumeName -}}
{{- $zeekVol := .zeekVolumeName -}}
{{- $curlrcVol := .curlrcVolumeName | default "pcap-monitor-opensearch-curlrc-secret-volume" -}}

- name: {{ $name }}
  image: "{{ include "malcolm.pcapMonitor.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  env:
{{ toYaml $env | nindent 4 }}
  ports:
    - name: zmq
      protocol: TCP
      containerPort: 30441
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
{{- if eq $mode "monitor" }}
    - configMapRef: { name: opensearch-env }
    - configMapRef: { name: upload-common-env }
{{- else }}
    - configMapRef: { name: upload-pcap-offline-env }
{{- end }}
{{ include "malcolm.pcapMonitor.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
{{- if eq $mode "monitor" }}
    - mountPath: /var/local/curlrc/secretmap
      name: {{ $curlrcVol }}
{{- end }}
    - mountPath: "/pcap"
      name: {{ $pcapVol }}
    - mountPath: "/zeek"
      name: {{ $zeekVol }}
{{- end -}}