{{/* Shared strelka-frontend image */}}
{{- define "malcolm.strelkaFrontend.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.strelka_frontend_container_override | default (printf "%s/strelka-frontend:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared livenessProbe */}}
{{- define "malcolm.strelkaFrontend.livenessProbe" -}}
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
Generic strelka-frontend container (emits a list item).

Params:
  root: $
  name: string (default strelka-frontend-container)
  valkeySecretName: string (default valkey-env)
  configVolumeName: string (required)
  extraVolumeMounts: list (optional)   # e.g. logs mount in the standalone deployment
  securityContext: map (optional)
*/}}
{{- define "malcolm.strelkaFrontend.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "strelka-frontend-container" -}}
{{- $valkeySecret := .valkeySecretName | default "valkey-env" -}}
{{- $cfgVol := .configVolumeName -}}
{{- $extraMounts := .extraVolumeMounts | default (list) -}}
{{- $sc := .securityContext | default (dict) -}}
{{- $mergedSc := merge (dict "runAsGroup" 0 "runAsUser" 0) $sc -}}

- name: {{ $name }}
  image: "{{ include "malcolm.strelkaFrontend.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $mergedSc | nindent 4 }}
  ports:
    - name: enqueue
      containerPort: 57314
      protocol: TCP
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - secretRef: { name: {{ $valkeySecret }} }
    - configMapRef: { name: pipeline-env }
{{ include "malcolm.strelkaFrontend.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
    - mountPath: "/etc/strelka/configmap"
      name: {{ $cfgVol }}
{{- with $extraMounts }}
{{ toYaml . | nindent 4 }}
{{- end }}
{{- end -}}