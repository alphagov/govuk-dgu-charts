#!/bin/bash
set -euo pipefail

# Export anonymized production snapshot for staging load testing
# Removes PII: passwords, API tokens, email addresses
# Usage: bash export-anonymized-production-data.sh

echo "=== Exporting anonymized production data ==="

# Configuration
EXPORT_DIR="${EXPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
EXPORT_FILE="${EXPORT_DIR}/production-snapshot-anonymized-${TIMESTAMP}.sql"

# Production database connection via AWS RDS
PROD_DB_HOST="${PROD_DB_HOST:-ckan-prod.c0a1b2c3d4e5.eu-west-1.rds.amazonaws.com}"
PROD_DB_PORT="${PROD_DB_PORT:-5432}"
PROD_DB_NAME="${PROD_DB_NAME:-ckan_prod}"
PROD_DB_USER="${PROD_DB_USER:-ckan_user}"

echo "Connecting to production database: $PROD_DB_HOST:$PROD_DB_PORT/$PROD_DB_NAME"

# Export tables with anonymization applied
pg_dump \
  -h "$PROD_DB_HOST" \
  -p "$PROD_DB_PORT" \
  -U "$PROD_DB_USER" \
  -d "$PROD_DB_NAME" \
  --no-password \
  --disable-triggers \
  -a \
  --exclude-table-data="package_revision" \
  --exclude-table-data="resource_revision" \
  --exclude-table-data="package_extra_revision" \
  --exclude-table-data="activity" \
  > "$EXPORT_FILE"

echo "Anonymizing sensitive columns in $EXPORT_FILE..."

# Remove passwords, API tokens, email addresses
sed -i '' \
  -e "s/'password',[^,]*/'password','REDACTED'/g" \
  -e "s/'api_token',[^,]*/'api_token','REDACTED'/g" \
  -e "s/'email',[^,]*/'email','user@example.com'/g" \
  -e "s/'creator_user_id',[^,]*/'creator_user_id','anonymized'/g" \
  "$EXPORT_FILE"

# Verify no obvious PII remains
if grep -i "password\|token\|@.*\.gov\.uk\|@.*\.co\.uk" "$EXPORT_FILE" > /dev/null; then
  echo "⚠️  Warning: Potential PII found in export. Review manually."
else
  echo "✓ No obvious PII detected."
fi

echo "✓ Export complete: $EXPORT_FILE"
echo "✓ Size: $(du -h "$EXPORT_FILE" | cut -f1)"
echo ""
echo "Next: bash scripts/load-testing/import-to-staging.sh $EXPORT_FILE"
