# Use Debian Bookworm as base image
FROM debian:bookworm

# Install PHP-FPM and MySQL extension
RUN apt-get update && \
    apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Create directory for Adminer
RUN mkdir -p /var/www/adminer

# Download Adminer
RUN wget -O /var/www/adminer/index.php \
    https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php

# Set permissions
RUN chown -R www-data:www-data /var/www/adminer

# Configure PHP-FPM to listen on port 9000
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 9000|g' /etc/php/8.2/fpm/pool.d/www.conf

# Expose PHP-FPM port
EXPOSE 9000

# Start PHP-FPM in foreground
CMD ["php-fpm8.2", "-F"]