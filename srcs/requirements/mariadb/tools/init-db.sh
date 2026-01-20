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
    
    # Use bootstrap mode to initialize database and user
    echo "Creating database and user using bootstrap mode..."
    mysqld --user=mysql --bootstrap <<-EOSQL
        USE mysql;
        FLUSH PRIVILEGES;
        
        -- Set root password
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        
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
    echo "MariaDB initialization complete!"
else
    echo "Database '${MYSQL_DATABASE}' already exists - skipping initialization"
fi

echo "Starting MariaDB server..."
# Start MariaDB in foreground (PID 1)
exec mysqld --user=mysql --bind-address=0.0.0.0