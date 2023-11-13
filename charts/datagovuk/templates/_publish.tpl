{{- define "publish.environment-variables" -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
- name: CKAN_URL
  value: http://{{ .Values.publish.config.ckanReleaseName }}-ckan:5000
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.publish.config.sqlalchemyUrlSecretKeyRef.name }}
      key: {{ .Values.publish.config.sqlalchemyUrlSecretKeyRef.key }}
- name: ES_HOST
  value: http://{{ $.Release.Name }}-opensearch:9200
- name: RAILS_ENV
  value: {{ $environment }}
- name: REDIS_HOST
  value: {{ .Values.publish.config.ckanReleaseName }}-redis
- name: ES_INDEX
  value: datasets-{{ $environment }}
- name: RAILS_LOG_TO_STDOUT
  value: "1"
- name: CKAN_REDIRECTION_URL
  value: ckan
{{- end }}
