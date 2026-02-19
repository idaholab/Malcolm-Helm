{{/* Shared redis image */}}
{{- define "malcolm.redis.image" -}}
{{- $root := .root -}}
{{- $root.Values.image.redis_container_override | default (printf "%s/redis:%s" $root.Values.image.repository $root.Chart.AppVersion) -}}
{{- end -}}

{{/* Shared redis livenessProbe */}}
{{- define "malcolm.redis.livenessProbe" -}}
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

{{/* Main (AOF) redis args */}}
{{- define "malcolm.redis.args.main" -}}
{{- $root := .root -}}
{{- if $root.Values.is_production -}}
{{- with $root.Values.redis_env.production -}}
--dir /data --appendonly yes --appendfsync everysec --no-appendfsync-on-rewrite yes --auto-aof-rewrite-percentage 100 --auto-aof-rewrite-min-size 64mb --save '' --maxmemory {{ .max_memory }} --maxmemory-policy {{ .max_memory_policy }} --requirepass $(REDIS_PASSWORD)
{{- end -}}
{{- else -}}
{{- with $root.Values.redis_env.development -}}
--dir /data --appendonly yes --appendfsync everysec --no-appendfsync-on-rewrite yes --auto-aof-rewrite-percentage 100 --auto-aof-rewrite-min-size 64mb --save '' --maxmemory {{ .max_memory }} --maxmemory-policy {{ .max_memory_policy }} --requirepass $(REDIS_PASSWORD)
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Cache redis args */}}
{{- define "malcolm.redis.args.cache" -}}
{{- $root := .root -}}
{{- if $root.Values.is_production -}}
{{- with $root.Values.redis_env.production -}}
--save '' --appendonly no --maxmemory {{ .cache_max_memory }} --maxmemory-policy {{ .cache_max_memory_policy }} --maxmemory-samples 10 --lazyfree-lazy-eviction yes --timeout 300 --tcp-keepalive 60 --requirepass $(REDIS_PASSWORD)
{{- end -}}
{{- else -}}
{{- with $root.Values.redis_env.development -}}
--save '' --appendonly no --maxmemory {{ .cache_max_memory }} --maxmemory-policy {{ .cache_max_memory_policy }} --maxmemory-samples 10 --lazyfree-lazy-eviction yes --timeout 300 --tcp-keepalive 60 --requirepass $(REDIS_PASSWORD)
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generic redis container (emits a list item).
Params:
  root: $
  name: string
  port: int
  portName: string (optional; defaults to "redis")
  secretName: string
  mode: "main" | "cache"
  extraVolumeMounts: list (optional)
*/}}
{{- define "malcolm.redis.container" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $port := (.port | default $root.Values.redis_env.ports.local.persistent) -}}
{{- $portName := (.portName | default "redis") -}}
{{- $secret := (.secretName | default "redis-env") -}}
{{- $mode := (.mode | default "cache") -}}
{{- $extraMounts := (.extraVolumeMounts | default (list)) -}}
- name: {{ $name }}
  image: "{{ include "malcolm.redis.image" (dict "root" $root) }}"
  imagePullPolicy: "{{ $root.Values.image.pullPolicy }}"
  stdin: false
  tty: true
  command: ["/sbin/tini"]
  args:
    - "--"
    - "/usr/local/bin/docker-uid-gid-setup.sh"
    - "/usr/local/bin/service_check_passthrough.sh"
    - "-s"
    - "redis"
    - "sh"
    - "-c"
    - {{ if eq $mode "main" -}}
      "redis-server --port {{ $port }} {{ include "malcolm.redis.args.main" (dict "root" $root) | trim }}"
      {{- else -}}
      "redis-server --port {{ $port }} {{ include "malcolm.redis.args.cache" (dict "root" $root) | trim }}"
      {{- end }}
  ports:
    - name: {{ $portName }}
      protocol: TCP
      containerPort: {{ $port }}
  envFrom:
    - configMapRef: { name: process-env }
    - configMapRef: { name: ssl-env }
    - secretRef: { name: {{ $secret }} }
{{ include "malcolm.redis.livenessProbe" . | nindent 2 }}
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
{{- with $extraMounts }}
{{ toYaml . | nindent 4 }}
{{- end }}
{{- end -}}