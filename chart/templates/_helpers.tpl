{{/*
Gets elasticsearch password either from a defined secret or grabs the one specified 
in values.yaml file directly.
*/}}
{{- define "malcolm.elasticsearchpassword" -}}
    {{- if .Values.external_elasticsearch.password }}
        {{- printf "%s" .Values.external_elasticsearch.password }}
    {{- else if .Values.external_elasticsearch.elastic_secret_name }}
        {{- $elastic_secret := (lookup "v1" "Secret" .Values.external_elasticsearch.elastic_secret_namespace .Values.external_elasticsearch.elastic_secret_name).data }}
        {{- $elastic_password := get $elastic_secret .Values.external_elasticsearch.username | b64dec }}
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
Get Opensearch or Elasticsearch url short version (IE: opensearch:9200). 
*/}}
{{- define "malcolm.primaryurlshort" -}}
{{- if .Values.external_elasticsearch.enabled }}    
    {{- $parts := split "://" .Values.external_elasticsearch.url }}
    {{- printf "%s" $parts._1 }}
{{- else }}    
    {{- $parts := split "://" .Values.opensearch.url }}
    {{- printf "%s" $parts._1 }}
{{- end }}
{{- end }}


{{/*
Get Opensearch or Elasticsearch dashboards url short version (IE: dashboards:5601). 
*/}}
{{- define "malcolm.dashboardsurlshort" -}}
{{- if .Values.external_elasticsearch.enabled }}    
    {{- $parts := split "://" .Values.external_elasticsearch.dashboards_url }}
    {{- printf "%s" $parts._1 }}
{{- else }}    
    {{- $parts := split "://" .Values.opensearch.dashboards_url }}
    {{- $parts2 := split "/" $parts._1 }}
    {{- printf "%s" $parts2._0 }}
{{- end }}
{{- end }}


{{/*
Used for secret generation for the opensearch-curlrc Kubernetes secret
*/}}
{{- define "malcolm.curlrc" -}}
{{- if .Values.external_elasticsearch.username }}
    {{- $elastic_password := include "malcolm.elasticsearchpassword" . -}}
    {{- if $elastic_password }}
        {{- printf "--user %s:%s " .Values.external_elasticsearch.username $elastic_password | b64enc | quote }}
    {{- else }}
        {{- printf "--user %s " .Values.external_elasticsearch.username | b64enc | quote }}
    {{- end }}
{{- else }}
    {{- printf "" }}
{{- end }}
{{- end }}


