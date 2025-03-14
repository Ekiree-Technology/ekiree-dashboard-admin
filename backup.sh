#!/bin/bash

# Configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/mariadb_backup_$TIMESTAMP.sql.gz"
ENCRYPTED_BACKUP_FILE="$BACKUP_FILE.enc"
MYSQL_HOST="mariadb"

# Read MySQL credentials from Docker secrets
MYSQL_USER=$(cat /run/secrets/mysql_user)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)
MYSQL_DATABASE=$(cat /run/secrets/mysql_database)

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "Starting database backup..."
mariadb -h "$MYSQL_HOST" --user "$MYSQL_USER" --password "$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi

# Encrypt the backup using sops
echo "Encrypting backup with sops..."
sops --encrypt --age "$(cat /run/secrets/SOPS_ENCRYPTION_KEY)" "$BACKUP_FILE" > "$ENCRYPTED_BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Encryption successful: $ENCRYPTED_BACKUP_FILE"
    rm "$BACKUP_FILE"
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

