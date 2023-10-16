{{- define "ckan.environment-variables" -}}
{{- with .Values.ckan.config }}
- name: CKAN_SQLALCHEMY_URL
  valueFrom:
    secretKeyRef:
      name: {{ .sqlalchemyUrlSecretKeyRef.name }}
      key: {{ .sqlalchemyUrlSecretKeyRef.key }}
- name: CKAN_DB_INIT
  value: "{{ .dbInit | default "false" }}"
- name: CKAN_DB_HOST
  value: {{ .dbHost | default (print $.Release.Name "-postgres") }}
- name: CKAN_SOLR_URL
  value: {{ .solr.url | default (print "http://" $.Release.Name "-solr/solr/ckan") }}
- name: CKAN_SITE_ID
  value: {{ .site.id }}
- name: CKAN_SITE_URL
  value: {{ .site.url }}
- name: CKAN_SMTP_SERVER
  value: {{ .smtp.server }}
- name: CKAN_SMTP_STARTTLS
  value: "{{ .smtp.starttls }}"
- name: CKAN_SMTP_USER
  value: {{ .smtp.user }}
- name: CKAN_SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .smtp.passwordSecretKeyRef.name }}
      key: {{ .smtp.passwordSecretKeyRef.key }}
- name: CKAN_SMTP_MAIL_FROM
  value: {{ .smtp.mailFrom }}
- name: CKAN_CONFIG
  value: /config/
- name: CKAN_INI
  value: /config/production.ini
- name: CKAN_REDIS_URL
  value: redis://{{ .redis.host | default (print $.Release.Name "-redis") }}/{{ .redis.db_number | default "1" }}
  {{- if $.Values.dev.enabled }}
- name: CKAN_TEST_SYSADMIN_NAME
  value: ckan_admin_test
- name: CKAN_TEST_SYSADMIN_PASSWORD
  value: test1234
- name: CKAN_SYSADMIN_NAME
  value: ckan_admin
- name: CKAN_SYSADMIN_EMAIL
  value: ckan_admin@localhost
- name: CKAN_SYSADMIN_PASSWORD
  value: test1234
- name: CREATE_CKAN_ADMIN
  value: "1"
- name: SETUP_DGU_TEST_DATA
  value: "1"
  {{- end }}
{{- if not .s3.useIamServiceAccount }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .s3.credentials.awsAccessKeyIdSecretKeyRef.name }}
      key: {{ .s3.credentials.awsAccessKeyIdSecretKeyRef.key }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .s3.credentials.awsSecretAccessKeySecretKeyRef.name }}
      key: {{ .s3.credentials.awsSecretAccessKeySecretKeyRef.key }}
{{- end }}
{{- end }}
{{- end }}
