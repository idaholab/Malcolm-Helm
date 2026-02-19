{{/* Shared strelka-backend image */}}
{{- define "malcolm.strelkaBackend.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.strelka_backend_container_override | default (printf "%s/strelka-backend:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared livenessProbe */}}
{{- define "malcolm.strelkaBackend.livenessProbe" -}}
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
Generic strelka-backend container (emits a list item).

Params:
  root: $
  name: string (default strelka-backend-container)
  redisSecretName: string (default redis-env)
  configVolumeName: string (required)
  yaraVolumeName: string (optional; default strelka-backend-yara-rules-custom-volume)
*/}}
{{- define "malcolm.strelkaBackend.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "strelka-backend-container" -}}
{{- $redisSecret := .redisSecretName | default "redis-env" -}}
{{- $cfgVol := .configVolumeName -}}
{{- $yaraVol := .yaraVolumeName | default "strelka-backend-yara-rules-custom-volume" -}}

- name: {{ $name }}
  image: "{{ include "malcolm.strelkaBackend.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    runAsGroup: 0
    runAsUser: 0
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - secretRef: { name: {{ $redisSecret }} }
    - configMapRef: { name: pipeline-env }
{{ include "malcolm.strelkaBackend.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
    - mountPath: "/etc/strelka/configmap"
      name: {{ $cfgVol }}
    - mountPath: "/yara-rules/custom/configmap"
      name: {{ $yaraVol }}
{{- end -}}