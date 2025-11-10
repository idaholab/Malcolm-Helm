{{/*
Gets elasticsearch password either from a defined secret or grabs the one specified
in values.yaml file directly.
*/}}
{{- define "malcolm.elasticsearchpassword" -}}
    {{- if .Values.external_elasticsearch.password }}
        {{- printf "%s" .Values.external_elasticsearch.password }}
    {{- else if .Values.external_elasticsearch.elastic_secret_name }}
        {{- $elastic_secret := (lookup "v1" "Secret" .Values.external_elasticsearch.namespace .Values.external_elasticsearch.elastic_secret_name).data }}
        {{- $elastic_password := get $elastic_secret "password" | b64dec }}
        {{- printf "%s" $elastic_password }}
    {{- else }}
        {{- printf "%s" "" }}
    {{- end }}
{{- end }}


{{/*
Get whether or not opensearch is local or remote.
*/}}
{{- define "malcolm.opensearchprimary" -}}
    {{- if .Values.opensearch.enabled }}
        {{- printf "%s" "opensearch-local" }}
    {{- else if .Values.external_elasticsearch.enabled }}
        {{- printf "%s" "elasticsearch-remote" }}
    {{- else }}
        {{- printf "%s" "opensearch-local" }}
    {{- end }}
{{- end }}

{{/*
Get Opensearch or Elasticsearch url.
*/}}
{{- define "malcolm.opensearchprimaryurl" -}}
{{- if .Values.opensearch.enabled }}
    {{- printf "%s" .Values.opensearch.url }}
{{- else if .Values.external_elasticsearch.enabled }}
    {{- $url := .Values.external_elasticsearch.url }}
    {{- if .Values.external_elasticsearch.username }}
        {{- $parts := split "://" .Values.external_elasticsearch.url }}
        {{- $url := printf "%s://%s" $parts._0 .Values.external_elasticsearch.username }}
        {{- $elastic_password := include "malcolm.elasticsearchpassword" . -}}
        {{- if $elastic_password }}
            {{- $url = printf "%s:%s" $url $elastic_password }}
        {{- end }}
        {{- $url = printf "%s@%s" $url $parts._1 }}
        {{- printf "%s" $url }}
    {{- else }}
        {{- printf "%s" $url }}
    {{- end }}
{{- else }}
    {{- printf "%s" .Values.opensearch.url }}
{{- end }}
{{- end }}


{{/*
Get Opensearch or Elasticsearch dashboards url. TODO figure out a way to refactor this so
I am not duplicating this template code.
*/}}
{{- define "malcolm.dashboardsurl" -}}
{{- if .Values.opensearch.enabled }}
    {{- printf "%s" .Values.opensearch.dashboards_url }}
{{- else if .Values.external_elasticsearch.enabled }}
    {{- $url := .Values.external_elasticsearch.dashboards_url }}
    {{- if .Values.external_elasticsearch.username }}
        {{- $parts := split "://" .Values.external_elasticsearch.dashboards_url }}
        {{- $url := printf "%s://%s" $parts._0 .Values.external_elasticsearch.username }}
        {{- $elastic_password := include "malcolm.elasticsearchpassword" . -}}
        {{- if $elastic_password }}
            {{- $url = printf "%s:%s" $url $elastic_password }}
        {{- end }}
        {{- $url = printf "%s@%s" $url $parts._1 }}
        {{- printf "%s" $url }}
    {{- else }}
        {{- printf "%s" $url }}
    {{- end }}
{{- else }}
    {{- printf "%s" .Values.opensearch.dashboards_url }}
{{- end }}
{{- end }}


{{/*
Used for secret generation for the opensearch-curlrc Kubernetes secret
*/}}
{{- define "malcolm.curlrc" -}}
{{- if .Values.external_elasticsearch.username }}
    {{- $elastic_password := include "malcolm.elasticsearchpassword" . -}}
    {{- if $elastic_password }}
        {{- printf "--user %s:%s \n--insecure " .Values.external_elasticsearch.username $elastic_password | b64enc | quote }}
    {{- else }}
        {{- printf "--user %s \n--insecure " .Values.external_elasticsearch.username | b64enc | quote }}
    {{- end }}
{{- else }}
    {{- printf "" }}
{{- end }}
{{- end }}


{{- define "malcolm.nodeCount" -}}
{{- $labelKey := .Values.node_count_label.key | default "" }}
{{- $labelValue := .Values.node_count_label.value | default "" }}
{{- $nodeCount := 0 }}

{{- range $index, $obj := (lookup "v1" "Node" "" "").items }}
  {{- if index $obj.metadata.labels $labelKey | default "" | eq $labelValue }}
    {{- $nodeCount = add $nodeCount 1 }}
  {{- end }}
{{- end }}

{{- $nodeCount }}
{{- end }}


{{/*
Used to generate discovery seed hosts for opensearch
*/}}
{{- define "malcolm.discoverySeeds" }}
{{- $replicas := int (.Values.opensearch.replicas) }}
{{- range $index, $value := until $replicas -}}
opensearch-{{ $index }}.opensearch-headless.{{ $.Release.Namespace }}.svc.cluster.local:9300,
{{- end -}}
{{- end }}

{{/*
Used to generate manager nodes for opensearch
*/}}
{{- define "malcolm.managerNodes" }}
{{- $replicas := int (.Values.opensearch.replicas) }}
{{- range $index, $value := until $replicas -}}
opensearch-{{ $index }},
{{- end -}}
{{- end }}

{{/*
Generate extra secrets for database
*/}}
{{- define "netbox.databaseExtravars" }}
{{- range $index, $value := .Values.postgres.extra_secrets }}
apiVersion: v1
kind: Secret
type: Opaque
  {{- range $key, $value1 := $value }}
metadata:
  name: {{ $key }}
data:
    {{- range $key1, $value2 := $value1 }}
        {{- if $value2 }}
  {{ $key1 }}: {{ $value2 | b64enc }}
        {{- else }}
  {{ $key1 }}: {{ $.Values.postgres.password | b64enc }}
        {{- end }}
    {{- end }}
  {{- end }}
---
{{- end }}
{{- end }}

{{- define "malcolm.beatstemplate" }}
{
  "index_patterns" : ["{{ .index_patterns }}"],
  "composed_of": [
    "ecs_base",
    "ecs_ecs",
    "ecs_event",
    "ecs_agent",
    "ecs_client",
    "ecs_destination",
    "ecs_error",
    "ecs_file",
    "ecs_host",
    "ecs_http",
    "ecs_log",
    "ecs_network",
    "ecs_process",
    "ecs_related",
    "ecs_server",
    "ecs_source",
    "ecs_threat",
    "ecs_url",
    "ecs_user",
    "ecs_user_agent",
    "custom_miscbeat",
    "custom_suricata_stats",
    "custom_winlog",
    "custom_zeek_diagnostic"
  ],
  "template" :{
    "settings" : {
      "index" : {
        "lifecycle.name": "{{ .ilm_policy }}",
        "lifecycle.rollover_alias": "{{ .rollover_alias }}",
        "mapping.total_fields.limit" : "6000",
        "mapping.nested_fields.limit" : "250",
        "max_docvalue_fields_search" : "200",
        "default_pipeline": "{{ .default_pipeline }}"
      }
    },
    "mappings": {
      "properties": {
        "timestamp": { "type": "date" },
        "node": { "type": "keyword" },
        "event.result": { "type": "keyword" },
        "os.family": { "type": "keyword" },
        "os.type": { "type": "keyword" }
      }
    }
  }
}
{{- end }}

{{- define "malcolm.ecstemplate" }}
{
    "index_patterns" : ["{{ .index_patterns }}"],
    "composed_of": [
        "ecs_base",
        "ecs_ecs",
        "ecs_event",
        "ecs_agent",
        "ecs_client",
        "ecs_destination",
        "ecs_error",
        "ecs_file",
        "ecs_host",
        "ecs_http",
        "ecs_log",
        "ecs_network",
        "ecs_process",
        "ecs_related",
        "ecs_rule",
        "ecs_server",
        "ecs_source",
        "ecs_threat",
        "ecs_url",
        "ecs_vulnerability",
        "ecs_user_agent",
        "custom_arkime",
        "custom_suricata",
        "custom_zeek",
        "custom_zeek_ot",
        "custom_malcolm_common"
    ],
    "template" :{
        "aliases": {
            "{{ .search_alias }}": {}
        },
        "settings" : {
            "index": {
                "lifecycle.name": "{{ .ilm_policy }}",
                "lifecycle.rollover_alias": "{{ .rollover_alias }}",
                "mapping.total_fields.limit": "6000",
                "mapping.nested_fields.limit": "250",
                "max_docvalue_fields_search": "200",
                "number_of_shards": "{{ .number_of_shards }}",
                "number_of_replicas": "{{ .number_of_replicas }}"
            }
        }
  }
}
{{- end }}

{{/*
Template for the zeek-container in zeek-live DaemonSets
Parameters:
  .root - root context with Values
  .image - zeek container image
  .imagePullPolicy - image pull policy
*/}}
{{- define "malcolm.zeekLiveContainer" -}}
- name: zeek-container
  image: "{{ .image }}"
  imagePullPolicy: "{{ .imagePullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    capabilities:
      add:
        # NET_ADMIN and NET_RAW - to turn on promiscuous mode and capture raw packets
        - NET_ADMIN
        - NET_RAW
        # SYS_NICE - to set process nice values, real-time scheduling policies, I/O scheduling
        - SYS_NICE
  envFrom:
    {{- if ne (len .root.Values.zeek_live.extra_envFrom) 0 }}
    {{- toYaml .root.Values.zeek_live.extra_envFrom | nindent 4 }}
    {{- end }}
    - configMapRef:
        name: process-env
    - configMapRef:
        name: ssl-env
    - configMapRef:
        name: upload-common-env
    - configMapRef:
        name: zeek-env
    {{- if .root.Values.kafka.enabled }}
    - configMapRef:
        name: kafka-config
    {{- end }}
    - secretRef:
        name: zeek-secret-env
    - configMapRef:
        name: zeek-live-env
    - configMapRef:
        name: pcap-capture-env
  livenessProbe:
    exec:
      command:
      - /usr/local/bin/container_health.sh
    initialDelaySeconds: 600
    periodSeconds: 60
    timeoutSeconds: 30
    successThreshold: 1
    failureThreshold: 3
  env:
    {{- if ne (len .root.Values.zeek_live.extra_env) 0 }}
    {{- toYaml .root.Values.zeek_live.extra_env | nindent 4 }}
    {{- end }}
    - name: ZEEK_DISABLED
      value: "false"
    - name: PCAP_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume
    - mountPath: "/zeek/extract_files"
      name: zeek-live-zeek-volume
      subPath: "extract_files"
    - mountPath: "/zeek/live"
      name: zeek-live-logs-volume
      subPath: "live"
    - mountPath: "/opt/zeek/share/zeek/site/intel-preseed/configmap"
      name: zeek-live-intel-preseed-volume
    - mountPath: "/opt/zeek/share/zeek/site/intel"
      name: zeek-intel-volume
      subPath: "zeek/intel"
    {{- if ne (len .root.Values.zeek_chart_overrides.live_volumeMounts) 0 }}
    {{- toYaml .root.Values.zeek_chart_overrides.live_volumeMounts | nindent 4 }}
    {{- else }}
    - mountPath: "/opt/zeek/share/zeek/site/custom/configmap"
      name: zeek-custom-volume
    {{- end }}
{{- end }}

{{/*
Template for the dirinit init container in zeek-live DaemonSets
Parameters:
  .root - root context with Values
  .dirinit_image - dirinit container image
  .imagePullPolicy - image pull policy
  .puser_mkdir - PUSER_MKDIR environment variable value
*/}}
{{- define "malcolm.zeekLiveInitContainer" -}}
- name: zeek-live-dirinit-container
  image: "{{ .dirinit_image }}"
  imagePullPolicy: "{{ .imagePullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    runAsGroup: 0
    runAsUser: 0
  envFrom:
    - configMapRef:
        name: process-env
  env:
    - name: PUSER_MKDIR
      value: "{{ .puser_mkdir }}"
  volumeMounts:
    - name: zeek-intel-volume
      mountPath: "/data/config"
    - name: zeek-live-logs-volume
      mountPath: "/zeek-live-logs"
    - name: zeek-live-zeek-volume
      mountPath: "/data/zeek-shared"
{{- end }}

{{/*
Template for the file-monitor-container in zeek-live remotesensor DaemonSet
Parameters:
  .root - root context with Values
  .file_monitor_image - file monitor container image
  .imagePullPolicy - image pull policy
*/}}
{{- define "malcolm.zeekLiveFileMonitorContainer" -}}
- name: file-monitor-container
  image: "{{ .file_monitor_image }}"
  imagePullPolicy: "{{ .imagePullPolicy }}"
  stdin: false
  tty: true
  securityContext:
    # TODO we should not be using root here
    runAsGroup: 0
    runAsUser: 0
  ports:
    - name: clamav
      containerPort: 3310
      protocol: TCP
    - name: filetopic
      containerPort: 5987
      protocol: TCP
    - name: loggertopic
      containerPort: 5988
      protocol: TCP
    - name: http
      protocol: TCP
      containerPort: 8440
  envFrom:
    - configMapRef:
        name: dashboards-env
    - configMapRef:
        name: process-env
    - configMapRef:
        name: ssl-env
    - configMapRef:
        name: zeek-env
    - configMapRef:
        name: auth-common-env
    - secretRef:
        name: zeek-secret-env
  env:
    - name: VIRTUAL_HOST
      value: "file-monitor.malcolm.local"
    - name: ZEEK_LOG_DIRECTORY
      value: "/zeek/current"
    - name: EXTRACTED_FILE_HTTP_SERVER_ENABLE
      value: "false"
    - name: EXTRACTED_FILE_PRESERVATION
      value: "none"
  livenessProbe:
    exec:
      command:
      - /usr/local/bin/container_health.sh
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 15
    successThreshold: 1
    failureThreshold: 10
  volumeMounts:
    - mountPath: /var/local/ca-trust/configmap
      name: var-local-catrust-volume            
    - mountPath: "/zeek/extract_files"
      name: zeek-live-zeek-volume
      subPath: "extract_files"
    - mountPath: "/zeek/current"
      name: zeek-live-logs-volume
      subPath: "current"
    - mountPath: "/yara-rules/custom/configmap"
      name: file-monitor-yara-rules-custom-volume  
{{- end }}

{{/*
Template for volumes in zeek-live DaemonSets
Parameters:
  .root - root context with Values
  .volume_type - "pvc" or "emptyDir"
  .include_file_monitor_volumes - boolean, include file-monitor volumes
*/}}
{{- define "malcolm.zeekLiveVolumes" -}}
- name: var-local-catrust-volume
  configMap:
    name: var-local-catrust
{{- if .include_file_monitor_volumes }}
- name: file-monitor-yara-rules-custom-volume
  configMap:
    name: yara-rules
{{- end }}
- name: zeek-live-zeek-volume
  {{- if eq .volume_type "pvc" }}
  persistentVolumeClaim:
    claimName: zeek-claim
  {{- else }}
  emptyDir:
    sizeLimit: 50Mi
  {{- end }}
- name: zeek-live-intel-preseed-volume
  configMap:
    name: zeek-intel-preseed
- name: zeek-intel-volume
  {{- if eq .volume_type "pvc" }}
  persistentVolumeClaim:
    claimName: config-claim
  {{- else }}
  emptyDir:
    sizeLimit: 1Gi
  {{- end }}
- name: zeek-live-logs-volume
  hostPath:
    path: "{{ .root.Values.zeek_live.zeek_log_path }}"
    type: DirectoryOrCreate
{{- if ne (len .root.Values.zeek_chart_overrides.live_volumes) 0 }}
{{- toYaml .root.Values.zeek_chart_overrides.live_volumes | indent 0 }}
{{- else }}
- name: zeek-custom-volume
  configMap:
    name: zeek-custom
{{- end }}
{{- end }}

{{/*
Template for zeek-live DaemonSet
Parameters:
  .root - root context with Values
  .name - DaemonSet name
  .nodeSelector - nodeSelector values (from Values)
  .volume_type - "pvc" or "emptyDir"
  .puser_mkdir - PUSER_MKDIR value for init container
  .include_file_monitor - boolean, include file-monitor container
  .include_sidecars - boolean, include sideCars
  .zeek_image - zeek container image
  .dirinit_image - dirinit container image
  .file_monitor_image - file monitor container image
  .imagePullPolicy - image pull policy
*/}}
{{- define "malcolm.zeekLiveDaemonSet" }}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ .name }}
spec:
  selector:
    matchLabels:
      name: {{ .name }}
  template:
    metadata:
      labels:
        name: {{ .name }}
    spec:
      # Required for coredns to work with hostnetwork set to true.
      serviceAccountName: {{ .root.Values.zeek_chart_overrides.serviceAccountName | default "default" }}
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
      nodeSelector:
{{ toYaml .nodeSelector | indent 8 }}
{{- with .root.Values.live_capture.tolerations }}
      tolerations:
{{ toYaml . | indent 6 }}
{{- end }}
      containers:
      {{- include "malcolm.zeekLiveContainer" (dict "root" .root "image" .zeek_image "imagePullPolicy" .imagePullPolicy) | nindent 6 }}
      {{- if .include_sidecars }}
      {{- if ne (len .root.Values.zeek_chart_overrides.sideCars) 0 }}
      {{- toYaml .root.Values.zeek_chart_overrides.sideCars | nindent 6 }}
      {{- end }}
      {{- end }}
      {{- if .include_file_monitor }}
      {{- include "malcolm.zeekLiveFileMonitorContainer" (dict "root" .root "file_monitor_image" .file_monitor_image "imagePullPolicy" .imagePullPolicy) | nindent 6 }}
      {{- end }}
      initContainers:
      {{- if ne (len .root.Values.zeek_chart_overrides.extra_init_containers) 0 }}
      {{- toYaml .root.Values.zeek_chart_overrides.extra_init_containers | nindent 6 }}
      {{- end }}
      {{- include "malcolm.zeekLiveInitContainer" (dict "root" .root "dirinit_image" .dirinit_image "imagePullPolicy" .imagePullPolicy "puser_mkdir" .puser_mkdir) | nindent 6 }}
      volumes:
      {{- include "malcolm.zeekLiveVolumes" (dict "root" .root "volume_type" .volume_type "include_file_monitor_volumes" .include_file_monitor) | nindent 6 }}
{{- end }}