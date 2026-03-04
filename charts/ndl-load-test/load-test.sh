#!/bin/bash
# Ad hoc load test runner — deletes old Job and triggers new one with custom config
# Usage: ./load-test.sh [options]
# Examples:
#   ./load-test.sh --vus 25 --soak 10              # 25 VUs, 10 min soak
#   ./load-test.sh --vus 50 --query "housing"      # 50 VUs, search "housing"
#   ./load-test.sh --url "https://example.com"     # Test custom URL

set -euo pipefail

# Defaults
VUS=10
RAMP_DURATION=10
SOAK_DURATION=10
SEARCH_QUERY="climate"
API_QUERY="climate"
API_ROWS=5
BASE_URL="https://www.staging.data.gov.uk"
API_URL="https://ckan.eks.staging.govuk.digital"
HOMEPAGE_THRESHOLD=2000
SEARCH_THRESHOLD=2000
DATASET_THRESHOLD=2000
API_THRESHOLD=3000
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
      API_QUERY="$2"
      shift 2
      ;;
    --search-query)
      SEARCH_QUERY="$2"
      shift 2
      ;;
    --api-query)
      API_QUERY="$2"
      shift 2
      ;;
    --api-rows)
      API_ROWS="$2"
      shift 2
      ;;
    --url)
      BASE_URL="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --api-url)
      API_URL="$2"
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
    --api-threshold)
      API_THRESHOLD="$2"
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
  --query STRING            Search and API query (default: climate)
  --search-query STRING     Custom search query only
  --api-query STRING        Custom API query only
  --api-rows NUM            API result rows (default: 5)
  --url URL                 Base URL to test (default: staging)
  --api-url URL             API URL (default: staging CKAN)
  --search-threshold MS     Search p(95) threshold in ms (default: 2000)
  --dataset-threshold MS    Dataset p(95) threshold in ms (default: 2000)
  --api-threshold MS        API p(95) threshold in ms (default: 3000)
  --error-threshold RATE    Error rate threshold (default: 0.01)
  --help                    Show this help message

Examples:
  # 25 VU bisect test, 10 min soak
  ./load-test.sh --vus 25 --soak 10

  # Test different domain, relax thresholds
  ./load-test.sh --url "https://example.com" --search-threshold 3000

  # Test different search query
  ./load-test.sh --query "housing" --vus 50

  # Stress test: 5s thresholds, high error tolerance
  ./load-test.sh --vus 100 --search-threshold 5000 --error-threshold 0.05

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
echo "  Data.gov.uk:    ${BASE_URL}"
echo "  CKAN API:       ${API_URL}"
echo ""
echo "Queries:"
echo "  Search:         ${SEARCH_QUERY}"
echo "  API:            ${API_QUERY} (${API_ROWS} rows)"
echo ""
echo "Thresholds:"
echo "  Homepage:       p(95) < ${HOMEPAGE_THRESHOLD}ms"
echo "  Search:         p(95) < ${SEARCH_THRESHOLD}ms"
echo "  Dataset:        p(95) < ${DATASET_THRESHOLD}ms"
echo "  API:            p(95) < ${API_THRESHOLD}ms"
echo "  Error rate:     < ${ERROR_RATE_THRESHOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Deleting old Job and ConfigMap to allow clean Helm install..."
gds aws govuk-staging-dguengineer -- kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
gds aws govuk-staging-dguengineer -- kubectl delete configmap "${CONFIGMAP_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true

echo "Waiting for resources to be fully deleted..."
sleep 3

# Recreate helm release with new values
echo "Applying new configuration via Helm..."
gds aws govuk-staging-dguengineer -- helm upgrade ndl-load-test /Users/PuttanaA/Documents/AMAR-DSIT-NDL-WS/govuk-dgu-charts/charts/ndl-load-test \
  --install \
  --namespace "${NAMESPACE}" \
  --set "suspended=false" \
  --set "vus=${VUS}" \
  --set "rampDuration=${RAMP_DURATION}m" \
  --set "soakDuration=${SOAK_DURATION}m" \
  --set "baseUrl=${BASE_URL}" \
  --set "apiUrl=${API_URL}" \
  --set "searchQuery=${SEARCH_QUERY}" \
  --set "apiQuery=${API_QUERY}" \
  --set "apiRows=${API_ROWS}" \
  --set "thresholds.homePageThresholdMs=${HOMEPAGE_THRESHOLD}" \
  --set "thresholds.searchThresholdMs=${SEARCH_THRESHOLD}" \
  --set "thresholds.datasetThresholdMs=${DATASET_THRESHOLD}" \
  --set "thresholds.apiThresholdMs=${API_THRESHOLD}" \
  --set "thresholds.errorRateThreshold=${ERROR_RATE_THRESHOLD}"

echo ""
echo "✅ Load test started!"
echo ""
echo "Tailing logs in 5 seconds (Ctrl+C to stop)..."
echo "To view logs later: gds aws govuk-staging-dguengineer -- kubectl logs -n ${NAMESPACE} -l app=ndl-load-test -f"
echo ""
sleep 5

# Tail logs
gds aws govuk-staging-dguengineer -- kubectl logs -n "${NAMESPACE}" -l app=ndl-load-test -f --max-log-requests=5 || true

