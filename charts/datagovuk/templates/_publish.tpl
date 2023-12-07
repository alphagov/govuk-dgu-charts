{{- define "publish.environment-variables" -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
- name: FIND_URL
  value: {{ .Values.find.ingress.host }}
{{- with .Values.publish.config }}
- name: CKAN_URL
  value: http://{{ .ckanReleaseName }}-ckan:5000
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
  value: {{ .redis.host | default "ckan-redis" }}
- name: ES_INDEX
  value: datasets-{{ $environment }}
- name: RAILS_LOG_TO_STDOUT
  value: "1"
- name: CKAN_REDIRECTION_URL
  value: ckan
- name: SENTRY_DSN
  valueFrom:
    secretKeyRef:
      name: {{ .publishSentryDsnSecretKeyRef.name }}
      key: {{ .publishSentryDsnSecretKeyRef.key }}
- name: GOVUK_APP_DOMAIN
  value: "www.gov.uk"
{{- end }}
{{- end }}
