{{- define "datagovuk.environment-variables" -}}
{{- $eks_envs := eq .Values.environment "ephemeral" | ternary "ephemeral" $.Values.environment -}}
{{- $environment := eq $.Values.environment "test" | ternary "development" $eks_envs -}}
{{- $ephemeralPath := print $.Values.argo_environment ".ephemeral.govuk.digital" }}
{{- $stablePath := eq "production" $environment | ternary "publishing.service.gov.uk" (print $environment ".publishing.service.gov.uk")}}
{{- $environmentPath := eq .Values.environment "ephemeral" | ternary $ephemeralPath $stablePath -}}
{{/* note that ckan-dev is the release name provided when installing the ckan helm chart locally */}}
{{- $solr_url := eq .Values.environment "test" | ternary "http://ckan-dev-solr/solr/ckan" "http://ckan-solr/solr/ckan" -}}
- name: USE_DOCKER
  value: "True"
- name: DJANGO_ALLOWED_HOSTS
  value: "datagovuk.eks.{{ .Values.environment }}.govuk.digital,find.eks.{{ .Values.environment }}.govuk.digital,www.{{ $environment }}.data.gov.uk,www.data.gov.uk"
- name: SENTRY_ENVIRONMENT
  value: {{ $environment }}
- name: GOOGLE_TAG_MANAGER_ID
  value: GTM-5WRWCH8X
{{- if $.Values.dev.enabled }}
- name: DJANGO_SECURE_SSL_REDIRECT
  value: "False"
{{- end }}
{{- with .Values.datagovuk.config }}
{{ if ne $environment "production" }}
- name: BASIC_AUTH_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .basicAuthNameSecretKeyRef.name }}
      key: {{ .basicAuthNameSecretKeyRef.key }}
- name: BASIC_AUTH_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .basicAuthPasswordSecretKeyRef.name }}
      key: {{ .basicAuthPasswordSecretKeyRef.key }}
- name: BASIC_AUTH_BYPASS
  valueFrom:
    secretKeyRef:
      name: {{ .basicAuthBypassSecretKeyRef.name }}
      key: {{ .basicAuthBypassSecretKeyRef.key }}
{{- end }}
- name: DJANGO_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .djangoSecretKeyRef.name }}
      key: {{ .djangoSecretKeyRef.key }}
- name: SENTRY_DSN
  valueFrom:
    secretKeyRef:
      name: {{ .sentryDSNRef.name }}
      key: {{ .sentryDSNRef.key }}
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: SOLR_URL
  value: {{ $solr_url }}
- name: CKAN_DOMAIN
  value: ckan.{{ $environmentPath }}
- name: ZENDESK_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .zendeskApiKeySecretKeyRef.name }}
      key: {{ .zendeskApiKeySecretKeyRef.key }}
- name: ZENDESK_TICKET_URL
  valueFrom:
    secretKeyRef:
      name: {{ .zendeskTicketUrlSecretKeyRef.name }}
      key: {{ .zendeskTicketUrlSecretKeyRef.key }}
- name: NDL_ZENDESK_EMAIL
  valueFrom:
    secretKeyRef:
      name: {{ .ndlZendeskEmailSecretKeyRef.name }}
      key: {{ .ndlZendeskEmailSecretKeyRef.key }}
- name: NDL_ZENDESK_GROUP_ID
  valueFrom:
    secretKeyRef:
      name: {{ .ndlZendeskGroupIdSecretKeyRef.name }}
      key: {{ .ndlZendeskGroupIdSecretKeyRef.key }}
{{- end }}
{{- end }}
