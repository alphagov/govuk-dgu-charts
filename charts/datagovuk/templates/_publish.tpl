{{- define "publish.environment-variables" -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
{{- with .Values.publish.config }}
- name: CKAN_URL
  value: http://{{ .Values.publish.config.ckanReleaseName }}-ckan:5000
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .sqlalchemyUrlSecretKeyRef.name }}
      key: {{ .sqlalchemyUrlSecretKeyRef.key }}
- name: ES_HOST
  value: http://{{ $.Release.Name }}-opensearch:9200
- name: RAILS_ENV
  value: {{ $environment }}
- name: REDIS_HOST
  value: redis://{{ .redis.host | default (print "ckan-redis") }}/{{ .redis.db_number | default "1" }}
- name: ES_INDEX
  value: datasets-{{ $environment }}
- name: RAILS_LOG_TO_STDOUT
  value: "1"
- name: CKAN_REDIRECTION_URL
  value: ckan
{{- end }}
{{- end }}
