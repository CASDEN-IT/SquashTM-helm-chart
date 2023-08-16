{{/*
Expand the name of the chart.
*/}}
{{- define "AppCtx.chartName" -}}
{{- default .Chart.Name | trunc 24 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "AppCtx.chartNameVersion" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 30 chars in order to leave room for suffixes (because some Kubernetes name fields are limited to 63 chars by the DNS naming spec).
*/}}
{{- define "AppCtx.name" }}
{{- $name := default .Release.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 30 | trimSuffix "-"}}
{{- end }}

{{/*
Create the squash name
*/}}
{{- define "AppCtx.squashName" }}
{{- printf "%s-squash" (include "AppCtx.name" .) | trunc 63  }}
{{- end }}

{{/*
Create the squash auto name
*/}}
{{- define "AppCtx.squashautoName" }}
{{- printf "%s-squashauto" (include "AppCtx.name" .) | trunc 63  }}
{{- end }}


{{/*
Selector labels
*/}}
{{- define "AppCtx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "AppCtx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "AppCtx.labels" -}}
helm.sh/chart: {{ include "AppCtx.chartName" . }}
{{ include "AppCtx.selectorLabels" . }}
app.kubernetes.io/part-of: {{ include "AppCtx.chartName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "AppCtx.squashSelectorLabels" -}}
{{ include "AppCtx.selectorLabels" . }}
app.kubernetes.io/component: squash
{{- end }}

{{- define "AppCtx.squashautoSelectorLabels" -}}
{{ include "AppCtx.selectorLabels" . }}
app.kubernetes.io/component: squashauto
{{- end }}

{{- define "AppCtx.squashLabels" -}}
{{ include "AppCtx.squashSelectorLabels" . }}
app.kubernetes.io/part-of: {{ include "AppCtx.chartName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app/version: {{ .Values.squash.image.tag }}
{{- end }}

{{- define "AppCtx.squashautoLabels" -}}
{{ include "AppCtx.squashautoSelectorLabels" . }}
app.kubernetes.io/part-of: {{ include "AppCtx.chartName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app/version: {{ .Values.squashauto.image.tag }}
{{- end }}

{{/*
Proxy pluginb option
*/}}
{{- define "proxyOpt" -}}
{{- if .Values.proxy.enabled -}}
{{- printf " -e use_proxy=yes -e https_proxy=%s " (.Values.proxy.httpsProxy) }}
{{- else -}}
{{- printf " "}}
{{- end }}
{{- end }}

