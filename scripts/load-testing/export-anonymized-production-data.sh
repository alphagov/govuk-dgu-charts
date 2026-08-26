#!/bin/bash
# Export anonymized production snapshot for staging load testing
# Usage: ./export-anonymized-production-data.sh

set -e

OUTPUT_DIR="${1:-.}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
EXPORT_FILE="$OUTPUT_DIR/ckan_production_snapshot_$TIMESTAMP.sql"

echo "CKAN Production Data Export (Anonymized)"
echo "========================================"
echo "Export timestamp: $TIMESTAMP"
echo "Output file: $EXPORT_FILE"
echo ""

# Step 1: Export schema and data (metadata only, no sensitive content)
echo "1. Exporting schema..."
pg_dump \
  --username=ckan_readonly \
  --dbname=ckan_default \
  --host=prod-rds.internal \
  --schema=public \
  --schema-only \
  > "$EXPORT_FILE"

echo "2. Exporting table data (package, resource, organization, tag)..."
pg_dump \
  --username=ckan_readonly \
  --dbname=ckan_default \
  --host=prod-rds.internal \
  --data-only \
  --table="package" \
  --table="resource" \
  --table="organization" \
  --table="\"group\"" \
  --table="tag" \
  --table="tag_vocabulary" \
  --table="package_tag" \
  --table="group_extra" \
  --table="package_extra" \
  >> "$EXPORT_FILE"

echo "3. Removing sensitive columns from SQL dump..."

# Remove user passwords and API tokens
sed -i "s/'password': '[^']*'/'password': 'REDACTED'/g" "$EXPORT_FILE"
sed -i "s/'apikey': '[^']*'/'apikey': 'REDACTED'/g" "$EXPORT_FILE"
sed -i "s/'email': '[^']*'/'email': 'REDACTED@example.com'/g" "$EXPORT_FILE"

echo "4. Done"
echo ""
echo "Export file: $EXPORT_FILE"
echo "Size: $(du -h $EXPORT_FILE | cut -f1)"
echo ""
echo "Next step: ./import-to-staging.sh $EXPORT_FILE"
