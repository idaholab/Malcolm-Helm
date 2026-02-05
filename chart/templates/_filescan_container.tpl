{{/* Shared filescan image */}}
{{- define "malcolm.filescan.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.filescan_container_override | default (printf "%s/filescan:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared livenessProbe */}}
{{- define "malcolm.filescan.livenessProbe" -}}
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
Generic filescan container (emits a list item).

Params:
  root: $
  name: string (default filescan-container)
  redisSecretName: string (default redis-env)
  zeekVolumeName: string (required)   # filescan-zeek-volume vs zeek-live-zeek-volume
  logsVolumeName: string (required)   # filescan-logs-volume vs filescan-live-logs-volume
  extraEnv: list (optional)           # for zeek-live (http server disable, preservation)
*/}}
{{- define "malcolm.filescan.container" -}}
{{- $root := .root -}}
{{- $name := .name | default "filescan-container" -}}
{{- $redisSecret := .redisSecretName | default "redis-env" -}}
{{- $zeekVol := .zeekVolumeName -}}
{{- $logsVol := .logsVolumeName -}}
{{- $extraEnv := .extraEnv | default (list) -}}

- name: {{ $name }}
  image: "{{ include "malcolm.filescan.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    runAsGroup: 0
    runAsUser: 0
  ports:
    - name: health
      containerPort: 8001
      protocol: TCP
    - name: files
      protocol: TCP
      containerPort: 8006
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - configMapRef: { name: auth-common-env }
    - configMapRef: { name: zeek-env }
    - configMapRef: { name: pipeline-env }
    - secretRef: { name: {{ $redisSecret }} }
    - secretRef: { name: filescan-secret-env }
    - configMapRef: { name: filescan-env }
{{- if gt (len $extraEnv) 0 }}
  env:
{{ toYaml $extraEnv | nindent 4 }}
{{- end }}
{{ include "malcolm.filescan.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
    - mountPath: "/zeek/extract_files"
      name: {{ $zeekVol }}
      subPath: "extract_files"
    - mountPath: "/filescan/data/files"
      name: {{ $zeekVol }}
      subPath: "extract_files/filescan"
      readOnly: true
    - name: {{ $logsVol }}
      mountPath: /filescan/data/logs
      subPath: "filescan"
{{- end -}}