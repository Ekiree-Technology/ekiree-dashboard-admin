#!/bin/bash

# Configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$TIMESTAMP.sql.gz"
MYSQL_HOST="mariadb"

# Read MySQL credentials from Docker secrets
MYSQL_USER=$(cat /run/secrets/mysql_user)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)
MYSQL_DATABASE=$(cat /run/secrets/mysql_database)

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "Starting database backup..."
mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi

# Optional: Upload to S3
if [ "$USE_S3" = "true" ]; then
    S3_BUCKET_NAME=$(cat /run/secrets/S3_BUCKET_NAME)
    S3_ACCESS_KEY=$(cat /run/secrets/S3_ACCESS_KEY)
    S3_SECRET_KEY=$(cat /run/secrets/S3_SECRET_KEY)
    S3_BUCKET_ENDPOINT=$(cat /run/secrets/S3_BUCKET_ENDPOINT)

    echo "Uploading backup to S3 storage..."
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET_NAME/mariadb_backups/" --endpoint-url "$S3_BUCKET_ENDPOINT"

    if [ $? -eq 0 ]; then
        echo "Upload successful."
    else
        echo "Upload failed!"
    fi
fi

echo "Backup process completed."

