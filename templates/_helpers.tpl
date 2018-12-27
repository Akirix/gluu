{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "gluu.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "gluu.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gluu.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Creates the basic labels which everything has.
*/}}
{{- define "gluu.labels" -}}
app: {{ template "gluu.name" . }}
chart: {{ template "gluu.chart" . }}
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
{{- end -}}

{{/*
Return the proper image name
*/}}
{{- define "gluu.image" -}}
{{- $registryName := (default .Values.image.registry "docker.io") -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 doesn't support it, so we need to implement this if-else logic.
Also, we can't use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
        {{- printf "%s/%s:%s" .Values.global.imageRegistry $repositoryName $tag -}}
    {{- else -}}
        {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Creates a csv list of the ldap servers
*/}}
{{- define "gluu.ldaplist" -}}
{{- $local := dict "first" true -}}
{{- range $k, $v := . -}}{{- if not $local.first -}},{{- end -}}{{- printf "%s:%.f" $v.host $v.port -}}{{- $_ := set $local "first" false -}}{{- end -}}
{{- end -}}


{{/*
Creates consul env vars
*/}}
{{- define "gluu.commonvars" -}}
- name: GLUU_KUBERNETES_NAMESPACE
  value: {{ .Values.global.namespace }}
- name: GLUU_KUBERNETES_CONFIGMAP
  value: {{ .Values.global.configMapName }}
- name: GLUU_CONFIG_ADAPTER
  value: {{ .Values.global.configAdapter }}
{{- if eq .Values.global.configAdapter "consul" }}
{{- with .Values.global.consul }}
- name: GLUU_CONSUL_HOST # or GLUU_KV_HOST 
  value: {{ .host }}
- name: GLUU_CONSUL_PORT # or GLUU_KV_PORT 
  value: {{ .port | quote }}
- name: GLUU_CONSUL_CONSISTENCY
  value: {{ .consistency }}
- name: GLUU_CONSUL_SCHEME
  value: {{ .scheme }}
- name: GLUU_CONSUL_VERIFY
  value: {{ .verify }}
- name: GLUU_CONSUL_CACERT_FILE
  value: '/etc/certs/consul_ca.crt'
- name: GLUU_CONSUL_CERT_FILE
  value: '/etc/certs/consul_client.crt'
- name: GLUU_CONSUL_KEY_FILE
  value: '/etc/certs/consul_client.key'
- name: GLUU_CONSUL_TOKEN_FILE
  value: '/etc/certs/consul_token'
{{- end }}
{{- end }}
{{- end -}}