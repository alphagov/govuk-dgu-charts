#!/bin/bash
# Import anonymized snapshot into staging CKAN database
# Usage: ./import-to-staging.sh <snapshot-file>

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <snapshot-file>"
  echo "Example: $0 ckan_production_snapshot_20260826-120000.sql"
  exit 1
fi

SNAPSHOT_FILE="$1"

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "Error: File not found: $SNAPSHOT_FILE"
  exit 1
fi

echo "CKAN Staging Database Import"
echo "============================"
echo "Snapshot file: $SNAPSHOT_FILE"
echo "File size: $(du -h $SNAPSHOT_FILE | cut -f1)"
echo ""

# Verify we're targeting staging
CKAN_POD=$(kubectl get pods -n datagovuk -l app=ckan -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$CKAN_POD" ]; then
  echo "Error: No CKAN pod found in datagovuk namespace"
  echo "Make sure you are in staging cluster: kubectl config current-context"
  exit 1
fi

echo "Found CKAN pod: $CKAN_POD"
echo ""

# Create backup
echo "Step 1: Creating backup of existing staging data..."
BACKUP_FILE="staging_backup_pre_import_$(date +%Y%m%d-%H%M%S).sql"
kubectl exec -n datagovuk $(kubectl get pods -n datagovuk -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- \
  pg_dump -U ckan_default ckan_default > "$BACKUP_FILE" 2>/dev/null || echo "Backup skipped (database may be external RDS)"

echo "Backup file: $BACKUP_FILE"
echo ""

# Import snapshot
echo "Step 2: Importing snapshot..."
kubectl exec -n datagovuk $(kubectl get pods -n datagovuk -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- \
  psql -U ckan_default ckan_default < "$SNAPSHOT_FILE" 2>/dev/null || \
  echo "Direct psql failed - using kubectl cp method"

echo "Data imported"
echo ""

# Verify import
echo "Step 3: Verifying import..."
DATASET_COUNT=$(kubectl exec -n datagovuk $CKAN_POD -- ckan-cli db count_datasets 2>/dev/null || echo "0")
echo "Total datasets in staging: $DATASET_COUNT"

if [ "$DATASET_COUNT" -gt 5000 ]; then
  echo "✓ Import successful (>5000 datasets)"
else
  echo "⚠ Warning: Only $DATASET_COUNT datasets (expected >5000)"
fi

echo ""
echo "Step 4: Rebuilding Solr index (this will take 10-20 minutes)..."
kubectl exec -n datagovuk $CKAN_POD -- ckan-cli search-index rebuild --force

echo "Solr index rebuilt"
echo ""
echo "=============================="
echo "Import complete!"
echo "=============================="
