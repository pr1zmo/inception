#!/bin/bash
set -e

# Read FTP password from secrets
FTP_PASSWORD=$(cat /run/secrets/ftp_password)

echo "Setting up FTP server..."

# Check if FTP user already exists
if ! id -u "${FTP_USER}" >/dev/null 2>&1; then
    echo "Creating FTP user: ${FTP_USER}"
    
    # Create user with home directory pointing to WordPress files
    useradd -m -d /var/www/html -s /bin/bash "${FTP_USER}"
    
    # Set password
    echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
    
    # Set ownership of WordPress directory
    chown -R "${FTP_USER}:${FTP_USER}" /var/www/html
    
    echo "FTP user created successfully!"
else
    echo "FTP user already exists."
fi

echo "Starting vsftpd..."
# Start vsftpd in foreground
exec /usr/sbin/vsftpd /etc/vsftpd.conf