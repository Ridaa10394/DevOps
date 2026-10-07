{{/*
Base name for every resource in this chart = the release name.
(The reference chart wrote {{ .Release.Name }} by hand in every file.)
*/}}
{{- define "notes-chart.fullname" -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels - must never change between upgrades.
*/}}
{{- define "notes-chart.selectorLabels" -}}
app: {{ include "notes-chart.fullname" . }}
{{- end }}

{{/*
Common labels for all objects.
*/}}
{{- define "notes-chart.labels" -}}
{{ include "notes-chart.selectorLabels" . }}
environment: {{ .Values.app.environment }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
