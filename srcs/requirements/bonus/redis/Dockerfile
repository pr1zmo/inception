# Use Debian Bookworm as base image
FROM debian:bookworm

# Install Redis
RUN apt-get update && \
    apt-get install -y redis-server && \
    rm -rf /var/lib/apt/lists/*

# Configure Redis to accept connections from any host
RUN sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/g' /etc/redis/redis.conf && \
    sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf

# Expose Redis port
EXPOSE 6379

# Start Redis in foreground
CMD ["redis-server", "--protected-mode", "no", "--bind", "0.0.0.0"]