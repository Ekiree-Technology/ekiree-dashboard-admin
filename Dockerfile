FROM alpine:latest

# Install necessary packages and sops dependencies
RUN apk add --no-cache mysql-client gzip aws-cli bash cronie curl gnupg

# Install Mozilla SOPS
RUN curl -L -o /usr/local/bin/sops https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux \
    && chmod +x /usr/local/bin/sops

# Copy the backup script
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

# Ensure the cron directory exists
RUN mkdir -p /root/.cache/crontab

# Set up cron job and run the cron daemon
CMD echo '0 0 * * * /backup.sh' | crontab - && crond -f

