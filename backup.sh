#!/bin/bash

# Configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$TIMESTAMP.sql.gz"
ENCRYPTED_BACKUP_FILE="$BACKUP_FILE.enc"
MYSQL_HOST="mariadb"

# Read MySQL credentials from Docker secrets
MYSQL_USER=$(cat /run/secrets/MYSQL_USER)
MYSQL_PASSWORD=$(cat /run/secrets/MYSQL_PASSWORD)
MYSQL_DATABASE=$(cat /run/secrets/MYSQL_DATABASE)

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Ensure required commands are available
if ! command -v mariadb-dump &> /dev/null; then
    echo "mariadb-dump could not be found. Please ensure it is installed."
    exit 1
fi

if ! command -v sops &> /dev/null; then
    echo "sops could not be found. Please ensure it is installed."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "AWS CLI could not be found. Please ensure it is installed."
    exit 1
fi

# Perform backup
echo "Starting database backup..."
mariadb-dump -h "$MYSQL_HOST" --user "$MYSQL_USER" --password="$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi

# Encrypt the backup file locally before uploading
echo "Encrypting backup file with sops..."
sops --encrypt --age "$(cat /run/secrets/SOPS_ENCRYPTION_KEY)" "$BACKUP_FILE" > "$ENCRYPTED_BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Encryption successful: $ENCRYPTED_BACKUP_FILE"
    rm "$BACKUP_FILE"  # Remove unencrypted backup after encryption
else
    echo "Encryption failed!"
    exit 1
fi

# Optional: Upload to S3
if [ "$USE_S3" = "true" ]; then
    BACKUP_BUCKET_NAME=$(cat /run/secrets/BACKUP_BUCKET_NAME)
    BACKUP_ACCESS_KEY=$(cat /run/secrets/BACKUP_ACCESS_KEY)
    BACKUP_SECRET_KEY=$(cat /run/secrets/BACKUP_SECRET_KEY)
    BACKUP_BUCKET_ENDPOINT=$(cat /run/secrets/BACKUP_BUCKET_ENDPOINT)

    echo "Uploading encrypted backup to S3 storage..."
    AWS_ACCESS_KEY_ID="$BACKUP_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$BACKUP_SECRET_KEY" \
    aws s3 cp "$ENCRYPTED_BACKUP_FILE" "s3://$BACKUP_BUCKET_NAME/mariadb_backups/" --endpoint-url "$BACKUP_BUCKET_ENDPOINT"

    if [ $? -eq 0 ]; then
        echo "Upload successful."
    else
        echo "Upload failed!"
    fi
fi

echo "Backup process completed."
