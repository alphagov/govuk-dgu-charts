{{- define "find.environment-variables" -}}
{{- $eks_envs := eq .Values.environment "ephemeral" | ternary "ephemeral" $.Values.environment -}}
{{- $environment := eq $.Values.environment "test" | ternary "development" $eks_envs -}}
{{- $ephemeralPath := print $.Values.argo_environment ".ephemeral.govuk.digital" }}
{{- $stablePath := eq "production" $environment | ternary "publishing.service.gov.uk" (print $environment ".publishing.service.gov.uk")}}
{{- $environmentPath := eq .Values.environment "ephemeral" | ternary $ephemeralPath $stablePath -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
- name: CKAN_DOMAIN
  value: ckan.{{ $environmentPath }}
- name: ES_HOST
  value: http://{{ $.Release.Name }}-opensearch-sts
- name: ES_INDEX
  value: datasets-{{ $environment }}
- name: GOVUK_APP_DOMAIN
  value: "www.gov.uk"
- name: GOVUK_ENVIRONMENT_NAME
  value: {{ $environment }}
- name: GOVUK_PROMETHEUS_EXPORTER
  value: "force"
- name: GOVUK_WEBSITE_ROOT
  value: "https://www.gov.uk"
- name: RAILS_LOG_LEVEL
  value: "warn"
- name: RAILS_LOG_TO_STDOUT
  value: "1"
- name: RAILS_DEVELOPMENT_HOSTS
  value: {{ .Values.find.ingress.host }}
- name: RAILS_SERVE_STATIC_FILES
  value: "1"
{{- with .Values.find.config }}
{{- with .gaTrackingId }}
- name: GA_TRACKING_ID
  value: {{ . }}
{{- end }}
{{- with .googleTagManagerId }}
- name: GOOGLE_TAG_MANAGER_ID
  value: {{ . }}
{{- end }}
{{- with .googleTagManagerAuth }}
- name: GOOGLE_TAG_MANAGER_AUTH
  value: {{ . }}
{{- end }}
{{- with .googleTagManagerPreview }}
- name: GOOGLE_TAG_MANAGER_PREVIEW
  value: {{ . }}
{{- end }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ .secretKeyBaseSecretKeyRef.name }}
      key: {{ .secretKeyBaseSecretKeyRef.key }}
- name: SENTRY_DSN
  valueFrom:
    secretKeyRef:
      name: {{ .findSentryDsnSecretKeyRef.name }}
      key: {{ .findSentryDsnSecretKeyRef.key }}
- name: SOLR_URL
  value: {{ .solrUrl }}
- name: ZENDESK_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .zendeskApiKeySecretKeyRef.name }}
      key: {{ .zendeskApiKeySecretKeyRef.key }}
- name: ZENDESK_END_POINT
  value: "https://govuk.zendesk.com/api/v2"
- name: ZENDESK_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .zendeskUsernameSecretKeyRef.name }}
      key: {{ .zendeskUsernameSecretKeyRef.key }}
{{- end }}
{{- end }}
