#!/bin/bash
# Ad hoc load test runner — deletes old Job and triggers new one with custom config
# Usage: ./load-test.sh [options]
#   ./load-test.sh --vus 25 --soak 10                          # 25 VUs, 10 min soak
#   ./load-test.sh --vus 50 --query "housing"                  # 50 VUs, search "housing"
#   ./load-test.sh --url "https://www.staging.data.gov.uk"     # Test custom URL

set -euo pipefail

# Defaults
VUS=10
RAMP_DURATION=10
SOAK_DURATION=10
SEARCH_QUERY="climate"
CKAN_QUERY="climate"
CKAN_ROWS=5
DATAGOVUK_URL="https://www.staging.data.gov.uk"
CKAN_URL="https://ckan.eks.staging.govuk.digital"
HOMEPAGE_THRESHOLD=2000
SEARCH_THRESHOLD=2000
DATASET_THRESHOLD=2000
CKAN_API_THRESHOLD=3000
ERROR_RATE_THRESHOLD="0.01"
NAMESPACE="datagovuk"
JOB_NAME="ndl-load-test-k6"
CONFIGMAP_NAME="ndl-load-test-script"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --vus)
      VUS="$2"
      shift 2
      ;;
    --ramp)
      RAMP_DURATION="$2"
      shift 2
      ;;
    --soak)
      SOAK_DURATION="$2"
      shift 2
      ;;
    --query)
      SEARCH_QUERY="$2"
      CKAN_QUERY="$2"
      shift 2
      ;;
    --search-query)
      SEARCH_QUERY="$2"
      shift 2
      ;;
    --ckan-query)
      CKAN_QUERY="$2"
      shift 2
      ;;
    --ckan-rows)
      CKAN_ROWS="$2"
      shift 2
      ;;
    --datagovuk-url)
      DATAGOVUK_URL="$2"
      shift 2
      ;;
    --ckan-url)
      CKAN_URL="$2"
      shift 2
      ;;
    --search-threshold)
      SEARCH_THRESHOLD="$2"
      shift 2
      ;;
    --dataset-threshold)
      DATASET_THRESHOLD="$2"
      shift 2
      ;;
    --ckan-api-threshold)
      CKAN_API_THRESHOLD="$2"
      shift 2
      ;;
    --error-threshold)
      ERROR_RATE_THRESHOLD="$2"
      shift 2
      ;;
    --help)
      cat <<EOF
Usage: ./load-test.sh [OPTIONS]

Options:
  --vus NUM                 Virtual users (default: 10)
  --ramp MINUTES            Ramp-up duration (default: 10)
  --soak MINUTES            Soak duration (default: 10)
  --query STRING            Search and CKAN query (default: climate)
  --search-query STRING     Custom search query only
  --ckan-query STRING       Custom CKAN query only
  --ckan-rows NUM           CKAN result rows (default: 5)
  --datagovuk-url URL       Data.gov.uk URL to test (default: staging)
  --ckan-url URL            CKAN URL to test (default: staging CKAN)
  --search-threshold MS     Search p(95) threshold in ms (default: 2000)
  --dataset-threshold MS    Dataset p(95) threshold in ms (default: 2000)
  --ckan-api-threshold MS   CKAN API p(95) threshold in ms (default: 3000)
  --error-threshold RATE    Error rate threshold (default: 0.01)
  --help                    Show this help message

Examples:
  # 25 VU bisect test, 10 min soak
  ./load-test.sh --vus 25 --soak 10

  # Test different domain, relax thresholds
  ./load-test.sh --datagovuk-url "https://example.com" --search-threshold 3000

  # Test different search query
  ./load-test.sh --query "housing" --vus 50

  # Stress test: 5s thresholds, high error tolerance
  ./load-test.sh --vus 100 --search-threshold 5000 --error-threshold 0.05

  # Test internal services
  ./load-test.sh --datagovuk-url "http://datagovuk-find.datagovuk.svc.cluster.local:3000" --ckan-url "http://ckan-ckan.datagovuk.svc.cluster.local"

EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Load Test Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VUs:              ${VUS}"
echo "Ramp-up:          ${RAMP_DURATION} min"
echo "Soak:             ${SOAK_DURATION} min"
echo "Total duration:   ~$((5 + RAMP_DURATION + SOAK_DURATION + 5)) min"
echo ""
echo "URLs:"
echo "  Data.gov.uk:    ${DATAGOVUK_URL}"
echo "  CKAN:           ${CKAN_URL}"
echo ""
echo "Queries:"
echo "  Search:         ${SEARCH_QUERY}"
echo "  CKAN:           ${CKAN_QUERY} (${CKAN_ROWS} rows)"
echo ""
echo "Thresholds:"
echo "  Homepage:       p(95) < ${HOMEPAGE_THRESHOLD}ms"
echo "  Search:         p(95) < ${SEARCH_THRESHOLD}ms"
echo "  Dataset:        p(95) < ${DATASET_THRESHOLD}ms"
echo "  CKAN API:       p(95) < ${CKAN_API_THRESHOLD}ms"
echo "  Error rate:     < ${ERROR_RATE_THRESHOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Deleting old Job and ConfigMap to allow clean Helm install..."
gds aws govuk-staging-dguengineer -- kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
gds aws govuk-staging-dguengineer -- kubectl delete configmap "${CONFIGMAP_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true

echo "Waiting for resources to be fully deleted..."
sleep 3

# Render manifests locally via helm template, then apply with kubectl SSA --force-conflicts.
# This bypasses the Helm/ArgoCD SSA ownership conflict: helm template needs no cluster access,
# and kubectl apply --server-side --force-conflicts can override ArgoCD's field management.
echo "Rendering manifests and applying via kubectl..."
helm template ndl-load-test /Users/PuttanaA/Documents/AMAR-DSIT-NDL-WS/govuk-dgu-charts/charts/ndl-load-test \
  --namespace "${NAMESPACE}" \
  --set "suspended=false" \
  --set "vus=${VUS}" \
  --set "ramp_duration=${RAMP_DURATION}m" \
  --set "soak_duration=${SOAK_DURATION}m" \
  --set "datagovuk_url=${DATAGOVUK_URL}" \
  --set "ckan_url=${CKAN_URL}" \
  --set "search_query=${SEARCH_QUERY}" \
  --set "ckan_query=${CKAN_QUERY}" \
  --set "ckan_rows=${CKAN_ROWS}" \
  --set "thresholds.home_page_threshold_ms=${HOMEPAGE_THRESHOLD}" \
  --set "thresholds.search_threshold_ms=${SEARCH_THRESHOLD}" \
  --set "thresholds.dataset_threshold_ms=${DATASET_THRESHOLD}" \
  --set "thresholds.ckan_api_threshold_ms=${CKAN_API_THRESHOLD}" \
  --set "thresholds.error_rate_threshold=${ERROR_RATE_THRESHOLD}" | \
gds aws govuk-staging-dguengineer -- kubectl apply \
  --server-side \
  --force-conflicts \
  --namespace "${NAMESPACE}" \
  -f -

echo ""
echo "✅ Load test started!"
echo ""
echo "📊 Logs are being stored in persistent volume for audit purposes."
echo ""
echo "🔍 To access logs after test completion:"
echo "   # Check job status:"
echo "   gds aws govuk-staging-dguengineer -- kubectl get jobs -n ${NAMESPACE}"
echo ""
echo "   # View k6 summary logs:"
echo "   gds aws govuk-staging-dguengineer -- kubectl logs -n ${NAMESPACE} -l app=ndl-load-test"
echo ""
echo "   # Access detailed CSV results (after job completes):"
echo "   gds aws govuk-staging-dguengineer -- kubectl exec -n ${NAMESPACE} -it \$(kubectl get pods -n ${NAMESPACE} -l app=ndl-load-test -o jsonpath='{.items[0].metadata.name}') -- ls -la /logs/"
echo "   gds aws govuk-staging-dguengineer -- kubectl cp \$(kubectl get pods -n ${NAMESPACE} -l app=ndl-load-test -o jsonpath='{.items[0].metadata.name}'):/logs/k6-results.csv ./k6-results.csv"
echo ""
echo "   # View PVC details:"
echo "   gds aws govuk-staging-dguengineer -- kubectl get pvc -n ${NAMESPACE} -l app=ndl-load-test"
echo ""
echo "⏱️  Test will run for approximately $((5 + RAMP_DURATION + SOAK_DURATION + 5)) minutes."
echo "   Check job status periodically with: kubectl get jobs -n ${NAMESPACE}"

