{{/* Shared arkime image */}}
{{- define "malcolm.arkime.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.arkime_container_override | default (printf "%s/arkime:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared arkime livenessProbe */}}
{{- define "malcolm.arkime.livenessProbe" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 210
  periodSeconds: 90
  timeoutSeconds: 15
  successThreshold: 1
  failureThreshold: 10
{{- end -}}

{{/*
Generic arkime container (emits a list item).

Params:
  root: $
  name: string
  ports: list (optional)            # list of {name, protocol, containerPort}
  envFrom: list (required)          # full envFrom list (toYaml-able)
  securityContext: map (required)   # full securityContext map
  volumeMounts: list (required)     # full mount list
*/}}
{{- define "malcolm.arkime.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "arkime-container" -}}
{{- $pull := .pullPolicy | default $root.Values.image.pullPolicy -}}
{{- $ports := .ports | default (list) -}}
{{- $envFrom := .envFrom | default (list) -}}
{{- $env := .env | default (list) -}}
{{- $sc := .securityContext -}}
{{- $mounts := .volumeMounts | default (list) -}}

- name: {{ $name }}
  image: "{{ include "malcolm.arkime.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $pull }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $sc | nindent 4 }}
{{- if gt (len $ports) 0 }}
  ports:
{{ toYaml $ports | nindent 4 }}
{{- end }}
  envFrom:
{{ toYaml $envFrom | nindent 4 }}
{{ include "malcolm.arkime.livenessProbe" . | nindent 2 }}
  volumeMounts:
{{ toYaml $mounts | nindent 4 }}
{{- end -}}
