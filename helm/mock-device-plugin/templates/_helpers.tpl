{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "mock-device-plugin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mock-device-plugin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mock-device-plugin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mock-device-plugin.labels" -}}
helm.sh/chart: {{ include "mock-device-plugin.chart" . }}
{{ include "mock-device-plugin.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Template labels
*/}}
{{- define "mock-device-plugin.templateLabels" -}}
app.kubernetes.io/name: {{ include "mock-device-plugin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.selectorLabelsOverride }}
{{ toYaml .Values.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mock-device-plugin.selectorLabels" -}}
{{- if .Values.selectorLabelsOverride -}}
{{ toYaml .Values.selectorLabelsOverride }}
{{- else -}}
{{ include "mock-device-plugin.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Full image name with tag
*/}}
{{- define "mock-device-plugin.fullimage" -}}
{{- $tag := printf "v%s" .Chart.AppVersion }}
{{- .Values.image.repository -}}:{{- .Values.image.tag | default $tag -}}
{{- end }}