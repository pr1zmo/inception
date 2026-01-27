# Inception Project - Comprehensive Evaluation Guide

This document serves as a complete evaluation guide for the **Inception** project. It contains questions, answers, and explanations covering all aspects of Docker containerization, the project's architecture, and both mandatory and bonus requirements.

---

## Table of Contents

1. [Preliminaries](#preliminaries)
2. [General Instructions](#general-instructions)
3. [Docker Concepts & Theory](#docker-concepts--theory)
4. [Mandatory Part](#mandatory-part)
   - [NGINX Container](#nginx-container)
   - [WordPress Container](#wordpress-container)
   - [MariaDB Container](#mariadb-container)
5. [Networking](#networking)
6. [Volumes & Persistence](#volumes--persistence)
7. [Bonus Part](#bonus-part)
8. [Practical Commands for Evaluation](#practical-commands-for-evaluation)
9. [Common Pitfalls to Check](#common-pitfalls-to-check)

---

## Preliminaries

### Security Check

**Q: Are there any hardcoded passwords, API keys, or credentials in the repository?**

**A:** No. All sensitive data is stored in the `secrets/` directory as separate files:
- `db_password.txt` - Database user password
- `db_root_password.txt` - Database root password
- `ftp_password.txt` - FTP user password
- `wp_admin_password.txt` - WordPress admin password
- `wp_user_password.txt` - WordPress regular user password

These are mounted as Docker secrets and read at runtime using:
```bash
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
```

**Verification Command:**
```bash
# Search for potential hardcoded passwords (should return empty)
grep -r "password\s*=" --include="*.sh" --include="*.yaml" --include="Dockerfile" .
```

---

## General Instructions

### Directory Structure Check

**Q: Is the directory structure correct?**

**A:** Yes. The required structure is:
```
inception/
├── Makefile              # At root (✓)
├── README.md             # Documentation
├── secrets/              # Secret files
└── srcs/                 # All configuration files
    ├── docker-compose.yaml
    └── requirements/
        ├── mariadb/
        ├── nginx/
        ├── wordpress/
        └── bonus/
```

### Makefile Verification

**Q: Does the Makefile exist at the root and what does it do?**

**A:** Yes. The Makefile provides:
- `make all` / `make` - Build and start all containers
- `make down` - Stop containers
- `make clean` - Stop and remove volumes
- `make purge` - Complete cleanup
- `make re` - Rebuild everything
- `make dirs` - Create data directories

### Prohibited Settings Check

**Q: Does docker-compose.yml contain any prohibited settings?**

**A:** No prohibited settings are used:

| Prohibited | Status | Why Prohibited |
|------------|--------|----------------|
| `network: host` | ✗ Not used | Bypasses container network isolation |
| `links:` | ✗ Not used | Deprecated, use networks instead |
| `--link` | ✗ Not used | Deprecated option |

**Verification:**
```bash
grep -E "(network:\s*host|links:|--link)" srcs/docker-compose.yaml
# Should return nothing
```

### Prohibited Commands in Dockerfiles

**Q: Are there any prohibited commands like `tail -f`, `sleep infinity`, or background processes?**

**A:** No. All containers use proper foreground processes:

| Container | CMD/ENTRYPOINT | Status |
|-----------|---------------|--------|
| nginx | `nginx -g "daemon off;"` | ✓ Foreground |
| wordpress | `exec php-fpm8.2 -F` | ✓ Foreground (-F flag) |
| mariadb | `exec mysqld --user=mysql` | ✓ Foreground |
| redis | `redis-server ...` | ✓ Foreground |
| adminer | `php-fpm8.2 -F` | ✓ Foreground |
| ftp | `exec /usr/sbin/vsftpd` | ✓ Foreground |

**Why is this important?**
- Docker expects PID 1 to be the main process
- If PID 1 exits, the container stops
- `tail -f` and `sleep infinity` are hacks that don't properly handle signals
- Background processes (`&`) won't receive SIGTERM properly

### Base Image Check

**Q: What base image is used and is it compliant?**

**A:** All containers use `debian:bookworm` (Debian 12), which is:
- The current stable version (released June 2023)
- Compliant with the "penultimate stable version of Alpine or Debian" requirement
- Consistent across all services

**Verification:**
```bash
grep -r "^FROM" srcs/requirements/
```

---

## Docker Concepts & Theory

### Question 1: How do Docker and Docker Compose work?

**Answer:**

**Docker** is a platform for containerization that:
1. Uses **images** as blueprints containing the application and all dependencies
2. Creates **containers** which are isolated running instances of images
3. Uses **namespaces** for isolation (PID, Network, Mount, User, etc.)
4. Uses **cgroups** for resource limitation (CPU, Memory)
5. Shares the host kernel (unlike VMs)

**Docker Compose** is an orchestration tool that:
1. Defines multi-container applications in a single YAML file
2. Manages the entire application lifecycle (build, start, stop, logs)
3. Creates networks for inter-container communication
4. Handles dependencies between services (`depends_on`)
5. Manages volumes for persistent data

**In this project:**
```yaml
services:
  nginx:
    depends_on:
      - wordpress    # Waits for wordpress to start
  wordpress:
    depends_on:
      - mariadb      # Waits for mariadb to start
      - redis
```

---

### Question 2: What's the difference between using Docker images with vs. without Docker Compose?

**Answer:**

| Aspect | Without Compose | With Compose |
|--------|-----------------|--------------|
| Starting containers | `docker run` for each | `docker compose up` |
| Networks | Manual: `docker network create` | Automatic |
| Build | `docker build -t name .` | `docker compose build` |
| Environment | `-e VAR=value` for each | `env_file:` directive |
| Volumes | `-v source:dest` | Defined in YAML |
| Dependencies | Manual ordering | `depends_on:` |
| Scaling | Manual | `docker compose up --scale` |

**Example without Compose:**
```bash
docker network create inception_network
docker build -t mariadb ./requirements/mariadb
docker run -d --name mariadb --network inception_network -v mariadb_data:/var/lib/mysql mariadb
docker build -t wordpress ./requirements/wordpress
docker run -d --name wordpress --network inception_network --depends mariadb wordpress
# ... repeat for each service
```

**With Compose (this project):**
```bash
docker compose up -d --build
# That's it!
```

---

### Question 3: What are the benefits of Docker compared to Virtual Machines?

**Answer:**

| Aspect | Docker Containers | Virtual Machines |
|--------|-------------------|------------------|
| **Size** | MBs (shares kernel) | GBs (full OS) |
| **Startup** | Seconds | Minutes |
| **Performance** | Near-native | Hypervisor overhead |
| **Isolation** | Process-level | Hardware-level |
| **Resource usage** | Lightweight | Heavy |
| **Portability** | Image = same everywhere | VM images are large |
| **Density** | 100s per host | 10s per host |

**Key Differences Explained:**

1. **Architecture:**
   - VM: Hardware → Hypervisor → Guest OS → App
   - Docker: Hardware → Host OS → Docker Engine → Container

2. **Kernel:**
   - VM: Each VM has its own kernel
   - Docker: All containers share host kernel

3. **Use Cases:**
   - VM: Different OS requirements, strong isolation
   - Docker: Microservices, CI/CD, identical environments

---

### Question 4: What is the pertinence of the required directory structure?

**Answer:**

The structure `srcs/requirements/<service>/` is logical because:

1. **Separation of Concerns:**
   - Each service has its own directory
   - Configuration, scripts, and Dockerfile are co-located

2. **Maintainability:**
   - Easy to find service-specific files
   - Changes to one service don't affect others

3. **Build Context:**
   - Each Dockerfile has its own context
   - Only relevant files are sent to Docker daemon

4. **Security:**
   - Secrets are in a separate directory
   - `.env` is outside `srcs/` for protection

```
srcs/
└── requirements/
    ├── nginx/
    │   ├── Dockerfile        # Build instructions
    │   └── conf/
    │       └── nginx.conf    # Service configuration
    ├── wordpress/
    │   ├── Dockerfile
    │   └── tools/
    │       └── setup-wordpress.sh  # Initialization script
    └── mariadb/
        ├── Dockerfile
        └── tools/
            └── init-db.sh
```

---

## Mandatory Part

### NGINX Container

**Q: How does NGINX serve as the entry point?**

**A:** NGINX is configured as:
1. **Reverse proxy** - Routes requests to WordPress/Adminer
2. **SSL termination** - Handles TLS encryption
3. **Single entry point** - Only ports 443 and 8081 are exposed externally

**Q: How is TLS v1.2/v1.3 enforced?**

**A:** In `nginx.conf`:
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```
This explicitly allows ONLY TLSv1.2 and TLSv1.3, rejecting older versions.

**Verification Command:**
```bash
# Test TLS version (should work)
openssl s_client -connect localhost:443 -tls1_2 </dev/null 2>/dev/null | grep "Protocol"

# Test old TLS (should fail)
openssl s_client -connect localhost:443 -tls1 </dev/null 2>/dev/null | grep "Protocol"
```

**Q: How is SSL certificate generated?**

**A:** Self-signed certificate created during build:
```dockerfile
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=MA/ST=Marrakesh/L=BenGuerir/O=42/OU=42/CN=zelbassa.42.fr"
```

**Q: Does port 80 work?**

**A:** No! NGINX only listens on:
- Port 443 (HTTPS for WordPress)
- Port 8081 (HTTPS for Adminer)

There is no `listen 80;` directive, so HTTP is blocked.

**Q: Is there a running process that keeps the container alive properly?**

**A:** Yes, using `daemon off;`:
```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```
This keeps NGINX in the foreground as PID 1.

---

### WordPress Container

**Q: What is PHP-FPM and why is it used?**

**A:** PHP-FPM (FastCGI Process Manager) is:
- A PHP implementation for handling PHP requests
- Listens on port 9000 (TCP)
- Receives requests from NGINX via FastCGI protocol
- Processes PHP files and returns HTML

**Why not Apache?**
- NGINX + PHP-FPM is more performant
- Separates web server from PHP processing
- Allows independent scaling

**Q: How does WordPress connect to MariaDB?**

**A:** Using environment variables and secrets:
```bash
# In setup-wordpress.sh
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
wp config create \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${MYSQL_PASSWORD}" \
    --dbhost="${MYSQL_HOST}"
```

**Q: Is there NGINX inside the WordPress container?**

**A:** No! Verify with:
```bash
docker exec wordpress which nginx
# Should return nothing or "nginx not found"
```

**Q: Does the admin username contain "admin"?**

**A:** This depends on the `.env` file configuration. The setup uses `${WP_ADMIN_USER}` which should NOT contain "admin", "administrator", etc.

**Verification:**
```bash
docker exec wordpress wp user list --allow-root
```

---

### MariaDB Container

**Q: How is the database initialized?**

**A:** Using bootstrap mode in `init-db.sh`:
```bash
mysqld --user=mysql --bootstrap <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL
```

**Q: Is there NGINX inside the MariaDB container?**

**A:** No! Verify with:
```bash
docker exec mariadb which nginx
# Should return nothing
```

**Q: How to verify the database is not empty?**

**A:** Connect and check:
```bash
# Enter the container
docker exec -it mariadb mysql -u<user> -p<password>

# In MySQL prompt:
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT * FROM wp_users;
```

Expected tables include: `wp_users`, `wp_posts`, `wp_options`, `wp_comments`, etc.

---

## Networking

### Question: How does Docker networking work in this project?

**Answer:**

**Network Type:** Bridge network (default for user-defined networks)

```yaml
networks:
  inception_network:
    driver: bridge
```

**How it works:**
1. Docker creates a virtual bridge interface
2. Each container gets its own network namespace
3. Containers communicate using service names as DNS
4. Bridge network provides DNS resolution automatically

**Communication Flow:**
```
Browser → NGINX (443) → WordPress (9000) → MariaDB (3306)
                ↓
              Redis (6379)
```

**Verification Commands:**
```bash
# List networks
docker network ls

# Inspect network
docker network inspect inception_inception_network

# Test DNS resolution from a container
docker exec wordpress ping mariadb
docker exec wordpress ping redis
```

**Q: Why use a custom network instead of the default bridge?**

**A:**
| Default Bridge | Custom Network |
|---------------|----------------|
| No DNS resolution | Automatic DNS (service names) |
| Use `--link` (deprecated) | Just use container/service name |
| Less isolation | Better isolation |

---

## Volumes & Persistence

### Question: How are volumes configured?

**Answer:**

```yaml
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/wordpress

  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/mariadb
```

**Q: Why use bind mounts with `type: none`?**

**A:** This creates a named volume that maps directly to a host directory, providing:
- Data persists across container restarts
- Easy backup (just copy the directory)
- Visible on the host filesystem
- Required by project: `/home/login/data/`

**Q: How to verify persistence?**

1. Add a comment to WordPress
2. Restart containers: `docker compose down && docker compose up -d`
3. Verify the comment still exists
4. Reboot the machine
5. Start containers again
6. Verify data persists

**Verification Commands:**
```bash
# Check volume mount points
docker volume inspect inception_wordpress_data
docker volume inspect inception_mariadb_data

# List files in WordPress volume
ls -la /home/$USER/data/wordpress/

# List files in MariaDB volume
ls -la /home/$USER/data/mariadb/
```

---

## Bonus Part

### Redis Cache

**Q: What is Redis and why use it with WordPress?**

**A:** Redis is an in-memory data structure store used for:
- **Object caching** - Stores WordPress database query results
- **Session storage** - User session data
- **Reduces database load** - Cached queries don't hit MariaDB

**Implementation:**
```php
// Added to wp-config.php by setup script
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```

**Verification:**
```bash
# Check Redis is running
docker exec redis redis-cli ping
# Should return: PONG

# Check Redis has cached data
docker exec redis redis-cli keys "*"

# Monitor Redis activity
docker exec redis redis-cli monitor
```

---

### FTP Server

**Q: What is the FTP server used for?**

**A:** The vsftpd server allows:
- File management of WordPress files
- Uploading themes/plugins without web interface
- Accessing `/var/www/html` (WordPress directory)

**Configuration:**
```conf
# vsftpd.conf
pasv_enable=YES
pasv_min_port=21000
pasv_max_port=21010
local_enable=YES
write_enable=YES
```

**Verification:**
```bash
# Connect via FTP
ftp localhost 21
# Login with FTP_USER credentials
# Navigate and list WordPress files
```

---

### Static Website

**Q: What is the static website and how does it work?**

**A:** A Node.js Express server serving static HTML/CSS:
- Uses Node.js (not PHP as required)
- Serves `index.html` and `style.css`
- Runs on port 8082

**Why Node.js?**
- Demonstrates knowledge of multiple technologies
- Simple HTTP server without PHP

---

### Adminer

**Q: What is Adminer?**

**A:** Adminer is a lightweight database management tool:
- Single PHP file
- Alternative to phpMyAdmin
- Accessible via NGINX on port 8081

**Verification:**
```bash
# Access in browser
https://localhost:8081

# Login with MariaDB credentials
# Server: mariadb
# Username: from .env
# Password: from secrets
# Database: wordpress
```

---

### Extra Service: Uptime Kuma (cuma)

**Q: What is the extra service and why is it useful?**

**A:** Uptime Kuma is a monitoring tool that:
- Monitors all services (WordPress, MariaDB, etc.)
- Sends alerts if a service goes down
- Provides a dashboard for health visualization
- Runs on port 3001

**Justification:**
- Essential for production environments
- Demonstrates understanding of observability
- Proactive monitoring vs reactive troubleshooting

---

## Practical Commands for Evaluation

### Building and Starting

```bash
# Build and start all containers
make all
# or
docker compose -f srcs/docker-compose.yaml up -d --build

# Check running containers
docker compose ps
docker ps

# View logs
docker compose logs -f
docker logs nginx
```

### Inspecting Containers

```bash
# Enter a container
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh

# Check if NGINX exists in a container
docker exec wordpress which nginx
docker exec mariadb which nginx

# Check running processes
docker exec nginx ps aux
docker exec wordpress ps aux
```

### Networking

```bash
# List networks
docker network ls

# Inspect network
docker network inspect inception_inception_network

# Test connectivity
docker exec wordpress ping mariadb
docker exec wordpress ping redis
```

### Volumes

```bash
# List volumes
docker volume ls

# Inspect a volume
docker volume inspect inception_wordpress_data

# Check data directory
ls -la /home/$USER/data/
```

### TLS Verification

```bash
# Check SSL certificate
openssl s_client -connect localhost:443 </dev/null 2>/dev/null | openssl x509 -text

# Verify TLS version
openssl s_client -connect localhost:443 -tls1_2 </dev/null 2>/dev/null | grep Protocol
openssl s_client -connect localhost:443 -tls1_3 </dev/null 2>/dev/null | grep Protocol

# Verify old TLS fails
openssl s_client -connect localhost:443 -tls1 </dev/null 2>/dev/null | grep Protocol
# Should fail/be empty
```

### Database Verification

```bash
# Connect to MariaDB
docker exec -it mariadb mysql -uroot -p

# Check database exists
SHOW DATABASES;

# Check tables exist
USE wordpress;
SHOW TABLES;

# Check users exist
SELECT user_login, user_email FROM wp_users;
```

---

## Common Pitfalls to Check

### ❌ Things That Should NOT Exist

| Check | Command | Expected Result |
|-------|---------|-----------------|
| `network: host` in compose | `grep "network: host" docker-compose.yaml` | Empty |
| `links:` in compose | `grep "links:" docker-compose.yaml` | Empty |
| `tail -f` in scripts | `grep -r "tail -f" .` | Empty |
| `sleep infinity` in scripts | `grep -r "sleep infinity" .` | Empty |
| Background processes (`&`) | `grep -r "nginx &\|mysqld &" .` | Empty |
| NGINX in WordPress | `docker exec wordpress which nginx` | Not found |
| NGINX in MariaDB | `docker exec mariadb which nginx` | Not found |
| Port 80 listening | `docker exec nginx netstat -tlnp \| grep :80` | Empty |

### ✅ Things That MUST Exist

| Check | Command | Expected Result |
|-------|---------|-----------------|
| Custom network | `docker network ls \| grep inception` | Network listed |
| TLS on port 443 | `curl -k https://localhost:443` | WordPress page |
| SSL certificate | `openssl s_client -connect localhost:443` | Certificate info |
| WordPress installed | Visit `https://login.42.fr` | WordPress site (not installer) |
| Database with data | `docker exec mariadb mysql ... -e "SHOW TABLES"` | wp_* tables |
| Volumes mounted | `docker volume ls` | wordpress_data, mariadb_data |

---

## Configuration Modification Test

**Scenario:** The evaluator asks you to change a configuration (e.g., NGINX port).

**Steps:**
1. Modify the configuration file
2. Rebuild the affected container
3. Demonstrate the change works

**Example: Change NGINX HTTPS port from 443 to 8443**

```bash
# 1. Edit nginx.conf
# Change: listen 443 ssl; → listen 8443 ssl;

# 2. Edit docker-compose.yaml
# Change: - "443:443" → - "8443:8443"

# 3. Rebuild
docker compose down
docker compose up -d --build nginx

# 4. Verify
curl -k https://localhost:8443
```

---

## Summary Checklist

### Mandatory Requirements
- [ ] Makefile at root
- [ ] All configs in `srcs/`
- [ ] No prohibited settings (`network: host`, `links:`)
- [ ] No prohibited commands (`tail -f`, `sleep infinity`, `&`)
- [ ] Base image: Debian Bookworm or Alpine penultimate
- [ ] NGINX with TLSv1.2/1.3 only
- [ ] WordPress with php-fpm (no NGINX)
- [ ] MariaDB (no NGINX)
- [ ] Custom Docker network
- [ ] Volumes at `/home/login/data/`
- [ ] Data persists after reboot
- [ ] No hardcoded credentials

### Bonus Requirements
- [ ] Redis cache for WordPress
- [ ] FTP server with WordPress volume
- [ ] Static website (non-PHP)
- [ ] Adminer for database management
- [ ] Extra service with justification (Uptime Kuma)

---

*This evaluation guide covers all mandatory and bonus aspects of the Inception project. Good luck with your evaluation!*
