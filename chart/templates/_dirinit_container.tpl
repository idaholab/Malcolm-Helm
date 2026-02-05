{{/* Shared dirinit image */}}
{{- define "malcolm.dirinit.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.dirinit_container_override | default (printf "%s/dirinit:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/*
Generic dirinit initContainer (emits a list item).

Covers all observed variants across callers:
- name differs (e.g. redis-dirinit-container, zeek-live-dirinit-container, dirinit-container, etc.)
- env may contain PUSER_MKDIR, PUSER_COPY, PUSER_CHOWN (any subset)
- volumeMounts vary widely (including subPath mounts)

Params:
  root: $
  name: string (required)
  env: list (required)           # list of env entries (dicts with name/value)
  volumeMounts: list (required)  # list of volumeMount dicts (mountPath/name/subPath/readOnly/etc)
*/}}
{{- define "malcolm.dirinit.initContainer" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $env := .env | default (list) -}}
{{- $mounts := .volumeMounts | default (list) -}}

- name: {{ $name }}
  image: "{{ include "malcolm.dirinit.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    runAsGroup: 0
    runAsUser: 0
  envFrom:
    - configMapRef: { name: process-env }
{{- if gt (len $env) 0 }}
  env:
{{ toYaml $env | nindent 4 }}
{{- end }}
{{- if gt (len $mounts) 0 }}
  volumeMounts:
{{ toYaml $mounts | nindent 4 }}
{{- end }}
{{- end -}}