{{- define "ckan.pycsw-init" -}}
{{- $environment := hasPrefix "eph-" $.Values.environment | ternary "ephemeral" $.Values.environment -}}
initContainers:
  - name: config-set
    image: '{{ include "docker-uri" (dict "environment" $environment "app" "pycsw" "files" $.Files) }}'
    command: [ "/bin/sh", "-c", '. /init/init.sh']
    imagePullPolicy: Always
    env:
      {{- include "ckan.environment-variables" . | nindent 6 }}
    volumeMounts:
      - name: pycsw-cfg
        mountPath: /pycsw
        readOnly: true
      - name: production-ini
        mountPath: /map
        readOnly: true
      - name: config
        mountPath: /config
      - name: pycsw-init
        mountPath: /init
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
{{- end }}

{{- define "ckan.pycsw-volumes" -}}
volumes:
  - name: pycsw-cfg
    configMap:
      name: {{ .Release.Name }}-pycsw-cfg
  - name: pycsw-init
    configMap:
      name: {{ .Release.Name }}-pycsw-init
  - name: production-ini
    configMap:
      name: {{ .Release.Name }}-{{ .Values.ckan.ckanIniConfigMap }}
  - name: config
    emptyDir: {}
{{- end }}
