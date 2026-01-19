#!/bin/bash
set -e

# Read secrets
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/db_password)

echo "MariaDB initialization starting..."
echo "Database: ${MYSQL_DATABASE}"
echo "User: ${MYSQL_USER}"

# Check if database is already initialized
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "Database does not exist. Initializing..."
    
    # Initialize MariaDB data directory if needed
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "Installing MariaDB system tables..."
        mysql_install_db --user=mysql --datadir=/var/lib/mysql
    fi
    
    # Start MariaDB in background temporarily
    echo "Starting temporary MariaDB server..."
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking=0 &
    MYSQL_PID=$!
    
    # Wait for MariaDB to be ready
    echo "Waiting for MariaDB to start..."
    for i in {30..0}; do
        if mysqladmin ping &>/dev/null; then
            echo "MariaDB is ready!"
            break
        fi
        echo "Waiting... ($i)"
        sleep 1
    done
    
    if [ "$i" = 0 ]; then
        echo "MariaDB failed to start"
        exit 1
    fi
    
    # Create database and user
    echo "Creating database and user..."
    mysql -u root <<-EOSQL
        -- Set root password
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
        
        -- Create database
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        
        -- Create user with access from any host
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        
        -- Also create user for localhost
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';
        
        FLUSH PRIVILEGES;
EOSQL
    
    echo "Database and user created successfully!"
    
    # Stop temporary MariaDB
    echo "Stopping temporary server..."
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait $MYSQL_PID
    
    echo "MariaDB initialization complete!"
else
    echo "Database '${MYSQL_DATABASE}' already exists - skipping initialization"
fi

echo "Starting MariaDB server..."
# Start MariaDB in foreground (PID 1)
exec mysqld --user=mysql --console --bind-address=0.0.0.0