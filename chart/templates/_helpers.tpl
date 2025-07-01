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
            "max_docvalue_fields_search": "200"
            }
        }
  }
}
{{- end }}