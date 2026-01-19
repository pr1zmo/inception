FROM debian:bookworm

# Install MariaDB server
RUN apt-get update && \
    apt-get install -y \
    mariadb-server \
    mariadb-client && \
    rm -rf /var/lib/apt/lists/*

# Copy initialization script
COPY tools/init-db.sh /usr/local/bin/init-db.sh
RUN chmod +x /usr/local/bin/init-db.sh

# Create directory for MariaDB socket and pid
RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld
# MariaDB needs write permission to this directory

# Expose MariaDB port
EXPOSE 3306

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/init-db.sh"]