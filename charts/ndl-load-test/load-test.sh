#!/bin/bash
# Ad hoc load test runner — deletes old Job and triggers new one with custom config
# Usage: ./load-test.sh [options]
#   ./load-test.sh --vus 25 --soak 10                          # 25 VUs, 10 min soak
#   ./load-test.sh --vus 50 --query "housing"                  # 50 VUs, search "housing"
#   ./load-test.sh --url "https://www.staging.data.gov.uk"     # Test custom URL

set -euo pipefail

# Defaults
VUS=50
RAMP_DURATION=2
SOAK_DURATION=25
TEST_PROFILE="baseline"
ISOLATION_ENDPOINT=""
CKAN_URL="https://ckan.eks.staging.govuk.digital"
SEARCH_UI_THRESHOLD=500
PACKAGE_SEARCH_THRESHOLD=2000
PACKAGE_LIST_THRESHOLD=2000
PACKAGE_SHOW_THRESHOLD=3000
ORGANIZATION_SHOW_THRESHOLD=3000
HARVEST_SOURCE_LIST_THRESHOLD=2000
HARVEST_OBJECT_THRESHOLD=3000
ERROR_RATE_THRESHOLD="0.01"
NAMESPACE="datagovuk"
JOB_NAME="ndl-load-test-k6"
CONFIGMAP_NAME="ndl-load-test-script"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)
      TEST_PROFILE="$2"
      shift 2
      ;;
    --isolate)
      ISOLATION_ENDPOINT="$2"
      shift 2
      ;;
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
    --ckan-url)
      CKAN_URL="$2"
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
  --profile TYPE            Test profile: baseline, stress, isolation, sustained (default: baseline)
  --isolate ENDPOINT        For isolation profile, which endpoint to test (default: all)
  --vus NUM                 Virtual users (default: 50)
  --ramp MINUTES            Ramp-up duration in minutes (default: 2)
  --soak MINUTES            Soak duration in minutes (default: 25)
  --ckan-url URL            CKAN URL to test (default: staging CKAN)
  --error-threshold RATE    Error rate threshold (default: 0.01)
  --help                    Show this help message

Examples:
  # Run baseline profile (default)
  ./load-test.sh --profile baseline --vus 50 --soak 25

  # Run stress test with ramp to 100 VUs
  ./load-test.sh --profile stress

  # Isolate and test one endpoint at 50 VUs
  ./load-test.sh --profile isolation --isolate harvest_source_list

  # Run 2-hour sustained peak test at 75 VUs
  ./load-test.sh --profile sustained --vus 75 --soak 116

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
echo "Profile:          ${TEST_PROFILE}"
if [ -n "$ISOLATION_ENDPOINT" ]; then
  echo "Isolate:          ${ISOLATION_ENDPOINT}"
fi
echo "VUs:              ${VUS}"
echo "Ramp-up:          ${RAMP_DURATION} min"
echo "Soak:             ${SOAK_DURATION} min"
echo "CKAN URL:         ${CKAN_URL}"
echo "Error threshold:  ${ERROR_RATE_THRESHOLD}"
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
  --set "test_profile=${TEST_PROFILE}" \
  --set "isolation_endpoint=${ISOLATION_ENDPOINT}" \
  --set "vus=${VUS}" \
  --set "ramp_duration=${RAMP_DURATION}m" \
  --set "soak_duration=${SOAK_DURATION}m" \
  --set "ckan_url=${CKAN_URL}" \
  --set "thresholds.search_ui_threshold_ms=${SEARCH_UI_THRESHOLD}" \
  --set "thresholds.package_search_threshold_ms=${PACKAGE_SEARCH_THRESHOLD}" \
  --set "thresholds.package_list_threshold_ms=${PACKAGE_LIST_THRESHOLD}" \
  --set "thresholds.package_show_threshold_ms=${PACKAGE_SHOW_THRESHOLD}" \
  --set "thresholds.organization_show_threshold_ms=${ORGANIZATION_SHOW_THRESHOLD}" \
  --set "thresholds.harvest_source_list_threshold_ms=${HARVEST_SOURCE_LIST_THRESHOLD}" \
  --set "thresholds.harvest_object_threshold_ms=${HARVEST_OBJECT_THRESHOLD}" \
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

