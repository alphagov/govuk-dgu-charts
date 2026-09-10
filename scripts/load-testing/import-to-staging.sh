#!/bin/bash
set -euo pipefail

# Import anonymized production snapshot to staging and rebuild Solr index
# Usage: bash import-to-staging.sh /path/to/export.sql

if [[ $# -lt 1 ]]; then
  echo "Usage: bash import-to-staging.sh <export-file.sql>"
  exit 1
fi

EXPORT_FILE="$1"

if [[ ! -f "$EXPORT_FILE" ]]; then
  echo "Error: File not found: $EXPORT_FILE"
  exit 1
fi

echo "=== Importing anonymized data to staging ==="
echo "File: $EXPORT_FILE"
echo "Size: $(du -h "$EXPORT_FILE" | cut -f1)"

# Staging database connection
STAGING_DB_HOST="${STAGING_DB_HOST:-ckan-staging.c0a1b2c3d4e5.eu-west-1.rds.amazonaws.com}"
STAGING_DB_PORT="${STAGING_DB_PORT:-5432}"
STAGING_DB_NAME="${STAGING_DB_NAME:-ckan_staging}"
STAGING_DB_USER="${STAGING_DB_USER:-ckan_user}"

echo ""
echo "Creating backup of staging database..."
BACKUP_FILE="ckan_staging_backup_$(date +%Y%m%d_%H%M%S).sql"
pg_dump \
  -h "$STAGING_DB_HOST" \
  -p "$STAGING_DB_PORT" \
  -U "$STAGING_DB_USER" \
  -d "$STAGING_DB_NAME" \
  --no-password \
  > "$BACKUP_FILE"
echo "✓ Backup saved: $BACKUP_FILE"

echo ""
echo "Importing anonymized snapshot..."
psql \
  -h "$STAGING_DB_HOST" \
  -p "$STAGING_DB_PORT" \
  -U "$STAGING_DB_USER" \
  -d "$STAGING_DB_NAME" \
  --no-password \
  < "$EXPORT_FILE"
echo "✓ Import complete"

echo ""
echo "Rebuilding Solr search index (15-20 minutes)..."
# Access CKAN pod and trigger reindex
kubectl exec -n datagovuk deployment/ckan-ckan -- \
  bash -c "ckan-paster search-index rebuild -c /etc/ckan/default/ckan.ini" \
  || echo "⚠️  Manual Solr rebuild may be needed. Run from CKAN pod:"
echo ""
echo "  ckan-paster search-index rebuild -c /etc/ckan/default/ckan.ini"
echo ""

echo "Verifying data quality..."
# Check row counts
echo "Package count: $(psql -h "$STAGING_DB_HOST" -p "$STAGING_DB_PORT" -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -t -c "SELECT COUNT(*) FROM package WHERE state='active'" --no-password)"
echo "Resource count: $(psql -h "$STAGING_DB_HOST" -p "$STAGING_DB_PORT" -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -t -c "SELECT COUNT(*) FROM resource WHERE state='active'" --no-password)"

# Verify no PII leakage
PII_CHECK=$(psql -h "$STAGING_DB_HOST" -p "$STAGING_DB_PORT" -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -t -c "SELECT COUNT(*) FROM \"user\" WHERE email LIKE '%@%' AND email NOT LIKE '%example.com%'" --no-password)
if [[ "$PII_CHECK" -gt 0 ]]; then
  echo "⚠️  Warning: Potential email PII found ($PII_CHECK records)"
else
  echo "✓ No obvious email PII detected"
fi

echo ""
echo "=== Import complete ==="
echo "Staging database is ready for load testing."
echo "Next: Run 10 VU validation test"
