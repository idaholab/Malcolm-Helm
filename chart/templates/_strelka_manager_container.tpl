{{/* Shared strelka-manager image */}}
{{- define "malcolm.strelkaManager.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.strelka_manager_container_override | default (printf "%s/strelka-manager:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared livenessProbe */}}
{{- define "malcolm.strelkaManager.livenessProbe" -}}
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
Generic strelka-manager container (emits a list item).

Params:
  root: $
  name: string (default strelka-manager-container)
  valkeySecretName: string (default valkey-env)
  configVolumeName: string (required)
  securityContext: map (optional)
*/}}
{{- define "malcolm.strelkaManager.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "strelka-manager-container" -}}
{{- $valkeySecret := .valkeySecretName | default "valkey-env" -}}
{{- $cfgVol := .configVolumeName -}}
{{- $sc := .securityContext | default (dict) -}}
{{- $mergedSc := merge (dict "runAsGroup" 0 "runAsUser" 0) $sc -}}

- name: {{ $name }}
  image: "{{ include "malcolm.strelkaManager.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $mergedSc | nindent 4 }}
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - secretRef: { name: {{ $valkeySecret }} }
    - configMapRef: { name: pipeline-env }
{{ include "malcolm.strelkaManager.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
    - mountPath: "/etc/strelka/configmap"
      name: {{ $cfgVol }}
{{- end -}}