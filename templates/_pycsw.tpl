{{- define "ckan.pycsw-init" -}}
initContainers:
  - name: config-set
    image: {{ .Values.ckan.image }}
    command: [ "/bin/sh", "-c", '. /init/init.sh']
    imagePullPolicy: Always
    env:
      {{- include "ckan.environment-variables" . | nindent 6 }}
      - name: CKAN_BEAKER_SESSION_SECRET
        valueFrom:
          secretKeyRef:
            name: {{ .Values.ckan.config.beakerSessionSecretKeyRef.name }}
            key: {{ .Values.ckan.config.beakerSessionSecretKeyRef.key }}
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
      name: {{ .Release.Name }}-ckan-production-ini
  - name: config
    emptyDir: {}
{{- end }}