FROM alpine:latest

# Install necessary packages
RUN apk add --no-cache mysql-client gzip aws-cli bash cronie

# Copy the backup script
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

# Ensure the cron directory exists
RUN mkdir -p /root/.cache/crontab

# Set up cron job and run the cron daemon
CMD echo '0 0 * * * /backup.sh' | crontab - && crond -f
