{{- define "docker-uri" -}}
{{- $repo := .files.Get (printf "images/%s/%s.yaml" .environment .app) | fromYaml -}}
{{ $repo.repository}}:{{ $repo.tag }}
{{- end -}}
