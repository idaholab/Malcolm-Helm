{{/* Shared valkey image */}}
{{- define "malcolm.valkey.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.valkey_container_override | default (printf "%s/valkey:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared valkey livenessProbe */}}
{{- define "malcolm.valkey.livenessProbe" -}}
livenessProbe:
  exec:
    command:
      - /usr/local/bin/container_health.sh
  initialDelaySeconds: 45
  periodSeconds: 60
  timeoutSeconds: 15
  successThreshold: 1
  failureThreshold: 10
{{- end -}}

{{/* Main (AOF) valkey args */}}
{{- define "malcolm.valkey.args.main" -}}
{{- $root := .root -}}
{{- if $root.Values.is_production -}}
{{- with $root.Values.valkey_env.production -}}
--dir /data --appendonly yes --appendfsync everysec --no-appendfsync-on-rewrite yes --auto-aof-rewrite-percentage 100 --auto-aof-rewrite-min-size 64mb --save '' --maxmemory {{ .max_memory }} --maxmemory-policy {{ .max_memory_policy }} --requirepass $(VALKEY_PASSWORD)
{{- end -}}
{{- else -}}
{{- with $root.Values.valkey_env.development -}}
--dir /data --appendonly yes --appendfsync everysec --no-appendfsync-on-rewrite yes --auto-aof-rewrite-percentage 100 --auto-aof-rewrite-min-size 64mb --save '' --maxmemory {{ .max_memory }} --maxmemory-policy {{ .max_memory_policy }} --requirepass $(VALKEY_PASSWORD)
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Cache valkey args */}}
{{- define "malcolm.valkey.args.cache" -}}
{{- $root := .root -}}
{{- if $root.Values.is_production -}}
{{- with $root.Values.valkey_env.production -}}
--save '' --appendonly no --maxmemory {{ .cache_max_memory }} --maxmemory-policy {{ .cache_max_memory_policy }} --maxmemory-samples 10 --lazyfree-lazy-eviction yes --timeout 300 --tcp-keepalive 60 --requirepass $(VALKEY_PASSWORD)
{{- end -}}
{{- else -}}
{{- with $root.Values.valkey_env.development -}}
--save '' --appendonly no --maxmemory {{ .cache_max_memory }} --maxmemory-policy {{ .cache_max_memory_policy }} --maxmemory-samples 10 --lazyfree-lazy-eviction yes --timeout 300 --tcp-keepalive 60 --requirepass $(VALKEY_PASSWORD)
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generic valkey container (emits a list item).
Params:
  root: $
  name: string
  port: int
  portName: string (optional; defaults to "valkey")
  secretName: string
  mode: "main" | "cache"
  extraVolumeMounts: list (optional)
  securityContext: map (optional)
*/}}
{{- define "malcolm.valkey.container" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $port := (.port | default $root.Values.valkey_env.ports.local.persistent) -}}
{{- $portName := (.portName | default "valkey") -}}
{{- $secret := (.secretName | default "valkey-env") -}}
{{- $mode := (.mode | default "cache") -}}
{{- $extraMounts := (.extraVolumeMounts | default (list)) -}}
{{- $sc := .securityContext | default (dict) -}}
{{- $mergedSc := merge (dict "runAsGroup" 0 "runAsUser" 0) $sc -}}

- name: {{ $name }}
  image: "{{ include "malcolm.valkey.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  securityContext:
{{ toYaml $mergedSc | nindent 4 }}
  command: ["/sbin/tini"]
  args:
    - "--"
    - "/usr/local/bin/docker-uid-gid-setup.sh"
    - "/usr/local/bin/service_check_passthrough.sh"
    - "-s"
    - "valkey"
    - "sh"
    - "-c"
    - {{ if eq $mode "main" -}}
      "valkey-server --port {{ $port }} {{ include "malcolm.valkey.args.main" (dict "root" $root) | trim }}"
      {{- else -}}
      "valkey-server --port {{ $port }} {{ include "malcolm.valkey.args.cache" (dict "root" $root) | trim }}"
      {{- end }}
  ports:
    - name: {{ $portName }}
      protocol: TCP
      containerPort: {{ $port }}
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - secretRef: { name: {{ $secret }} }
{{ include "malcolm.valkey.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
{{- with $extraMounts }}
{{ toYaml . | nindent 4 }}
{{- end }}
{{- end -}}