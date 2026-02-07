#!/bin/bash
set -e

# Read secrets
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until mysql -h"${MYSQL_HOST%:*}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    echo "MariaDB is unavailable - sleeping"
    sleep 3
done
echo "MariaDB is up and running!"

# Check if WordPress is already installed
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "WordPress not found. Installing..."
    
    # Download WordPress
    wp core download --allow-root --path=/var/www/html
    
    # Create wp-config.php
    wp config create \
        --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOST}" \
        --path=/var/www/html
    
    # Install WordPress
    wp core install \
        --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception WordPress" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path=/var/www/html
    
    # Create second user (non-admin)
    wp user create \
        --allow-root \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --path=/var/www/html
    
    echo "WordPress installation complete!"
    
    # Configure Redis cache if Redis is available
    if [ ! -z "${REDIS_HOST}" ]; then
        echo "Configuring Redis cache..."
        
        # Install Redis Object Cache plugin
        wp plugin install redis-cache --activate --allow-root --path=/var/www/html
        
        # Add Redis configuration to wp-config.php
        wp config set WP_REDIS_HOST "${REDIS_HOST%:*}" --allow-root --path=/var/www/html
        wp config set WP_REDIS_PORT "${REDIS_HOST#*:}" --raw --allow-root --path=/var/www/html
        wp config set WP_CACHE true --raw --allow-root --path=/var/www/html
        
        # Enable Redis cache
        wp redis enable --allow-root --path=/var/www/html
        
        echo "Redis cache configured!"
    fi
else
    echo "WordPress already installed."
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "Starting PHP-FPM..."
# Start PHP-FPM in foreground (PID 1)
exec php-fpm8.2 -F