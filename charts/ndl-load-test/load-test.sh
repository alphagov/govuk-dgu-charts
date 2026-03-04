#!/bin/bash
# Ad hoc load test runner — updates Job env vars and triggers the test
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
ERROR_RATE_THRESHOLD=0.01
NAMESPACE="datagovuk"
JOB_NAME="ndl-load-test-k6"

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

# Build stages JSON
STAGES=$(cat <<EOF
[
  {"duration":"5m","target":1},
  {"duration":"${RAMP_DURATION}m","target":${VUS}},
  {"duration":"${SOAK_DURATION}m","target":${VUS}},
  {"duration":"5m","target":0}
]
EOF
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Load Test Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VUs:              ${VUS}"
echo "Ramp-up:          ${RAMP_DURATION} min"
echo "Soak:             ${SOAK_DURATION} min"
echo "Total duration:   ~$((5 + RAMP_DURATION + SOAK_DURATION + 5)) min"
echo ""
echo "URLs:"
echo "  Base:           ${BASE_URL}"
echo "  API:            ${API_URL}"
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
echo "  Error rate:     < ${ERROR_RATE_THRESHOLD} (< $((ERROR_RATE_THRESHOLD * 100))%)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse AWS credentials using gds
eval "$(gds aws govuk-staging-dguengineer -- sh -c 'echo KUBECONFIG_CMD=\"gds aws govuk-staging-dguengineer -- \"')"

# Unsuspend the job
echo ""
echo "Unsuspending Job..."
gds aws govuk-staging-dguengineer -- kubectl patch job "${JOB_NAME}" -n "${NAMESPACE}" \
  --type=merge -p '{"spec":{"suspend":false}}' 2>/dev/null || echo "⚠ Job already running or not found"

# Update environment variables
echo "Setting environment variables..."
gds aws govuk-staging-dguengineer -- kubectl set env job/"${JOB_NAME}" \
  -n "${NAMESPACE}" \
  BASE_URL="${BASE_URL}" \
  API_URL="${API_URL}" \
  SEARCH_QUERY="${SEARCH_QUERY}" \
  API_QUERY="${API_QUERY}" \
  API_ROWS="${API_ROWS}" \
  HOMEPAGE_THRESHOLD_MS="${HOMEPAGE_THRESHOLD}" \
  SEARCH_THRESHOLD_MS="${SEARCH_THRESHOLD}" \
  DATASET_THRESHOLD_MS="${DATASET_THRESHOLD}" \
  API_THRESHOLD_MS="${API_THRESHOLD}" \
  ERROR_RATE_THRESHOLD="${ERROR_RATE_THRESHOLD}" \
  --overwrite=true

echo ""
echo "✅ Load test started!"
echo ""
echo "Tailing logs in 3 seconds (Ctrl+C to stop)..."
echo "To view logs later: gds aws govuk-staging-dguengineer -- kubectl logs -n ${NAMESPACE} -l app=ndl-load-test -f"
echo ""
sleep 3

# Tail logs
gds aws govuk-staging-dguengineer -- kubectl logs -n "${NAMESPACE}" -l app=ndl-load-test -f --max-log-requests=5
