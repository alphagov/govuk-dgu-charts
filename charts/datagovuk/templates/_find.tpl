{{- define "find.environment-variables" -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
- name: ES_HOST
  value: http://{{ $.Release.Name }}-opensearch
- name: RAILS_ENV
  value: {{ $environment }}
- name: ES_INDEX
  value: datasets-{{ $environment }}
- name: RAILS_LOG_TO_STDOUT
  value: "1"
- name: RAILS_DEVELOPMENT_HOSTS
  value: {{ .Values.find.ingress.host }}
{{- end }}
