# Use Debian Bookworm as base image
FROM debian:bookworm

# Install NGINX and OpenSSL
RUN apt-get update && \
    apt-get install -y \
    nginx \
    openssl && \
    rm -rf /var/lib/apt/lists/*

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Generate self-signed SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=MA/ST=Marrakesh/L=BenGuerir/O=42/OU=42/CN=zelbassa.42.fr"

# Remove default site
RUN rm -f /etc/nginx/sites-enabled/default

# Copy NGINX configuration
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Expose HTTPS for wordpress and HTTP for amdiner
EXPOSE 443 8081

# Start NGINX in foreground
CMD ["nginx", "-g", "daemon off;"]