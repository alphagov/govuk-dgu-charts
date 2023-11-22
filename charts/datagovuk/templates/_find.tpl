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
- name: RAILS_SERVE_STATIC_FILES
  value: "1"
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.find.config.secretKeyBaseSecretKeyRef.name }}
      key: {{ .Values.find.config.secretKeyBaseSecretKeyRef.key }}
- name: SENTRY_DSN
  valueFrom:
    secretKeyRef:
      name: {{ .sentryDsnSecretKeyRef.name }}
      key: {{ .sentryDsnSecretKeyRef.key }}
- name: ZENDESK_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.find.config.zendeskApiKeySecretKeyRef.name }}
      key: {{ .Values.find.config.zendeskApiKeySecretKeyRef.key }}
- name: ZENDESK_END_POINT
  value: "https://govuk.zendesk.com/api/v2"
- name: ZENDESK_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.find.config.zendeskUsernameSecretKeyRef.name }}
      key: {{ .Values.find.config.zendeskUsernameSecretKeyRef.key }}
{{- end }}
