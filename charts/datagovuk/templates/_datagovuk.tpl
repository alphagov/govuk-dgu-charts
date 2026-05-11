{{- define "datagovuk.environment-variables" -}}
{{- $environment := eq .Values.environment "test" | ternary "development" .Values.environment -}}
- name: USE_DOCKER
  value: "True"
- name: DJANGO_ALLOWED_HOSTS
  value: "datagovuk.eks.{{ .Values.environment }}.govuk.digital, www{{ $environment }}.data.gov.uk"
- name: SENTRY_ENVIRONMENT
  value: {{ $environment }}
- name: GOOGLE_TAG_MANAGER_ID
  value: GTM-5WRWCH8X
{{- if $.Values.dev.enabled }}
- name: DJANGO_SECURE_SSL_REDIRECT
  value: "False"
{{- end }}
{{- with .Values.datagovuk.config }}
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
{{- end }}
{{- end }}
