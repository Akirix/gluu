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
{{- $hosts := .Values.global.ldap.extraHosts -}}
{{- $genLdap := dict "host" (printf "%s-%s" .Release.Name .Values.global.ldap.type) "port" 1389.00 -}}
{{- $hosts := prepend $hosts $genLdap -}}
{{- $local := dict "first" true -}}
{{- range $k, $v := $hosts -}}
{{- if not $local.first -}},{{- end -}}{{- printf "%s:%.f" $v.host $v.port -}}{{- $_ := set $local "first" false -}}
{{- end -}}
{{- end -}}


{{/*
Creates consul env vars
*/}}
{{- define "gluu.commonvars" -}}
- name: GLUU_KUBERNETES_NAMESPACE
  value: {{ .Values.global.namespace | quote }}
- name: GLUU_KUBERNETES_CONFIGMAP
  value: {{ .Values.global.configMapName | quote }}
- name: GLUU_CONFIG_ADAPTER
  value: {{ .Values.global.configAdapter | quote }}
{{- if eq .Values.global.configAdapter "consul" }}
{{- with .Values.global.consul }}
- name: GLUU_CONSUL_HOST # or GLUU_KV_HOST 
  value: {{ .host | quote }}
- name: GLUU_CONSUL_PORT # or GLUU_KV_PORT 
  value: {{ .port | quote }}
- name: GLUU_CONSUL_CONSISTENCY
  value: {{ .consistency | quote }}
- name: GLUU_CONSUL_SCHEME
  value: {{ .scheme | quote }}
- name: GLUU_CONSUL_VERIFY
  value: {{ .verify | quote }}
- name: GLUU_CONSUL_CACERT_FILE
  value: "/etc/certs/consul_ca.crt"
- name: GLUU_CONSUL_CERT_FILE
  value: "/etc/certs/consul_client.crt"
- name: GLUU_CONSUL_KEY_FILE
  value: "/etc/certs/consul_client.key"
- name: GLUU_CONSUL_TOKEN_FILE
  value: "/etc/certs/consul_token"
{{- end }}
{{- end }}
{{- end -}}

{{/*
Get the correct storage class for something with a storage class field
*/}}
{{- define "gluu.storageClass" -}}
{{- if .storageClass -}}
{{- if (eq "-" .storageClass) -}}
""
{{- else -}}
{{- printf "%s" .storageClass | quote -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Creates a PV
*/}}
{{- define "gluu.pv" -}}
{{- if and (and .enabled .provisioner.enabled) (not .existingClaim) }}
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ .fullName }}
  namespace: "{{ .namespace }}"
  labels:
    volume: {{ .name }}
{{ .labels | indent 4 }}
spec:
  capacity:
    storage: {{ .size | quote }}
  volumeMode: Filesystem
  storageClassName: {{ template "gluu.storageClass" . }}
  accessModes:
  {{- range .accessModes }}
    - {{ . | quote }}
  {{- end }}
  persistentVolumeReclaimPolicy: Recycle
  {{ .provisioner.type }}:
{{ toYaml .provisioner.spec | indent 4 }}
{{- end }}
{{- end -}}

{{/*
Creates a PVC Template for a stateful set
*/}}
{{- define "gluu.pvc" -}}
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ .fullName }}
  namespace: "{{ .namespace }}"
  labels:
    volume: {{ .name }}
{{ .labels | indent 4 }}
spec:
  accessModes:
  {{- range .accessModes }}
    - {{ . | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ .size | quote }}
  storageClassName: {{ template "gluu.storageClass" . }}
{{- if and .provisioner.enabled (not .existingClaim) }}
  selector:
    matchLabels: 
      volume: {{ .name }}
{{ .labels | indent 6 }}
{{- end }}
{{- end -}}