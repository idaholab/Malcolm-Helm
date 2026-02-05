{{/* Shared filebeat image */}}
{{- define "malcolm.filebeat.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.filebeat_container_override | default (printf "%s/filebeat-oss:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{- define "malcolm.filebeat.livenessProbe" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 15
  successThreshold: 1
  failureThreshold: 10
{{- end -}}

{{/*
Generic filebeat container (emits a list item).

Params:
  root: $
  name: string (default filebeat-container)
  redisSecretName: string (default redis-env)
  ports: list (optional)                   # list of {name, protocol, containerPort}
  env: list (required)                     # env entries
  volumeMounts: list (required)            # full mounts list
*/}}
{{- define "malcolm.filebeat.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "filebeat-container" -}}
{{- $redisSecret := .redisSecretName | default "redis-env" -}}
{{- $ports := .ports | default (list) -}}
{{- $env := .env | default (list) -}}
{{- $mounts := .volumeMounts | default (list) -}}

- name: {{ $name }}
  image: "{{ include "malcolm.filebeat.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
{{- if gt (len $ports) 0 }}
  ports:
{{ toYaml $ports | nindent 4 }}
{{- end }}
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - configMapRef: { name: nginx-env }
    - secretRef:    { name: {{ $redisSecret }} }
    - configMapRef: { name: zeek-env }
    - configMapRef: { name: opensearch-env }
    - configMapRef: { name: upload-common-env }
    - configMapRef: { name: beats-common-env }
    - configMapRef: { name: netbox-common-env }
    - configMapRef: { name: filebeat-env }
  env:
{{ toYaml $env | nindent 4 }}
{{ include "malcolm.filebeat.livenessProbe" . | nindent 2 }}
  volumeMounts:
{{ toYaml $mounts | nindent 4 }}
{{- end -}}