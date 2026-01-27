# Inception - Developer Documentation

> **For Developers and System Administrators**

This guide explains how to set up, build, and manage the Inception infrastructure from scratch.

---

## 📋 Prerequisites

### System Requirements

- **OS:** Debian 12 (Bookworm) or compatible
- **RAM:** Minimum 2GB, recommended 4GB
- **Disk:** Minimum 10GB free space
- **Network:** Internet access for pulling packages

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Docker Engine | 24.0+ | Container runtime |
| Docker Compose | v2.20+ | Multi-container orchestration |
| Docker Buildx | 0.17.0+ | Build extensions |
| Make | 4.0+ | Build automation |
| Git | 2.0+ | Version control |

### Install Prerequisites on Debian 12

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y ca-certificates curl gnupg lsb-release git make sudo

# Add Docker repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify installation
docker --version
docker compose version
docker buildx version
```

---

## ⚙️ Configuration Files

### Environment Variables (`.env`)

Create the `.env` file at the project root:

```env
# Domain Configuration
DOMAIN_NAME=zelbassa.42.fr

# MariaDB Configuration
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb:3306

# WordPress Admin
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@zelbassa.42.fr

# WordPress User
WP_USER=author
WP_USER_EMAIL=author@zelbassa.42.fr

# Redis Configuration
REDIS_HOST=redis:6379

# FTP Configuration
FTP_USER=ftpuser

# System User (must match your Linux username)
USER=zelbassa
```

### Secrets Configuration

Create the `secrets/` directory with password files:

```bash
mkdir -p secrets

# Generate secure passwords (or use your own)
openssl rand -base64 24 > secrets/db_password.txt
openssl rand -base64 24 > secrets/db_root_password.txt
openssl rand -base64 24 > secrets/wp_admin_password.txt
openssl rand -base64 24 > secrets/wp_user_password.txt
openssl rand -base64 24 > secrets/ftp_password.txt

# Remove trailing newlines (important!)
for f in secrets/*.txt; do tr -d '\n' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done
```

### Hosts File

Add the domain to `/etc/hosts`:

```bash
make setup-hosts

# Or manually:
echo "127.0.0.1 zelbassa.42.fr" | sudo tee -a /etc/hosts
```

---

## 🏗️ Building and Launching

### Build and Start All Services

```bash
make all
```

This command:
1. Creates data directories in `/home/$USER/data/`
2. Builds all Docker images from Dockerfiles
3. Starts all containers in detached mode

### Build Without Cache (Fresh Build)

```bash
docker compose -f srcs/docker-compose.yaml build --no-cache
make all
```

### Start in Foreground (See Logs)

```bash
docker compose -f srcs/docker-compose.yaml up --build
```

---

## 🐳 Container Management

### Makefile Commands

| Command | Action |
|---------|--------|
| `make all` | Build and start all containers |
| `make down` | Stop all containers |
| `make clean` | Stop and remove volumes |
| `make purge` | Complete cleanup (images, volumes, data) |
| `make re` | Full rebuild (`purge` + `all`) |
| `make logs` | Follow all container logs |
| `make ps` | Show container status |

### Docker Compose Commands

```bash
# Define alias for convenience
DC="docker compose -f srcs/docker-compose.yaml"

# View all containers
$DC ps -a

# Restart a specific service
$DC restart nginx

# Rebuild a specific service
$DC build --no-cache wordpress
$DC up -d wordpress

# View logs for specific service
$DC logs -f mariadb

# Execute command in container
$DC exec wordpress sh
$DC exec mariadb mysql -u root -p
```

### Shell Access to Containers

```bash
make exec-nginx      # Enter nginx container
make exec-wordpress  # Enter wordpress container
make exec-mariadb    # Enter mariadb container

# Or directly:
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
```

---

## 📁 Data Storage and Persistence

### Volume Locations

Data persists in `/home/$USER/data/`:

| Directory | Service | Content |
|-----------|---------|---------|
| `/home/zelbassa/data/wordpress` | wordpress, nginx, ftp | WordPress files, themes, plugins, uploads |
| `/home/zelbassa/data/mariadb` | mariadb | Database files |
| `/home/zelbassa/data/cuma` | cuma | Uptime Kuma data |

### Docker Volume Configuration

Volumes are defined in `srcs/docker-compose.yaml`:

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

  cuma_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/cuma
```

### Inspect Volumes

```bash
# List all volumes
docker volume ls

# Inspect a volume
docker volume inspect srcs_wordpress_data

# Check disk usage
du -sh /home/zelbassa/data/*
```

### Backup Data

```bash
# Backup all data
sudo tar -czvf inception-backup-$(date +%Y%m%d).tar.gz /home/zelbassa/data/

# Backup database only
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) --all-databases > db-backup.sql
```

### Restore Data

```bash
# Restore from backup
sudo tar -xzvf inception-backup-20260127.tar.gz -C /

# Restore database
docker exec -i mariadb mysql -u root -p$(cat secrets/db_root_password.txt) < db-backup.sql
```

---

## 🔧 Project Structure

```
inception/
├── .env                          # Environment variables
├── .gitignore                    # Git ignore rules
├── Makefile                      # Build automation
├── README.md                     # Project overview
├── USER_DOC.md                   # User documentation
├── DEV_DOC.md                    # This file
├── evaluation.md                 # Evaluation guide
│
├── secrets/                      # Credentials (not in git)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── ftp_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
│
└── srcs/
    ├── docker-compose.yaml       # Service orchestration
    └── requirements/
        ├── nginx/                # Reverse proxy + TLS
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        │
        ├── wordpress/            # WordPress + PHP-FPM
        │   ├── Dockerfile
        │   └── tools/setup-wordpress.sh
        │
        ├── mariadb/              # Database
        │   ├── Dockerfile
        │   └── tools/init-db.sh
        │
        └── bonus/
            ├── redis/            # Cache
            │   ├── Dockerfile
            │   └── conf/redis.conf
            │
            ├── ftp/              # FTP server
            │   ├── Dockerfile
            │   ├── conf/vsftpd.conf
            │   └── tools/setup-ftp.sh
            │
            ├── adminer/          # DB admin UI
            │   └── Dockerfile
            │
            ├── static-site/      # Static website
            │   ├── Dockerfile
            │   ├── srcs/
            │   └── tools/
            │
            └── cuma/             # Uptime Kuma
                └── Dockerfile
```

---

## 🌐 Network Architecture

All services communicate through `inception_network`:

```
┌─────────────────────────────────────────────────────────────┐
│                     inception_network                        │
│                        (bridge)                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   nginx ◄────► wordpress ◄────► mariadb                     │
│     │              │                                         │
│     │              └─────────► redis                         │
│     │                                                        │
│     ├────────────► adminer ────► mariadb                    │
│     │                                                        │
│   ftp ────────────► (wordpress_data volume)                 │
│                                                              │
│   static-site     cuma                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Port Mappings

| Service | Internal Port | External Port |
|---------|---------------|---------------|
| nginx | 443 | 443 |
| nginx | 8081 | 8081 |
| static-site | 8082 | 8082 |
| cuma | 3001 | 3001 |
| ftp | 21 | 21 |
| ftp | 21000-21010 | 21000-21010 |

### Inspect Network

```bash
# List networks
docker network ls

# Inspect inception network
docker network inspect srcs_inception_network

# Test inter-container connectivity
docker exec nginx ping -c 2 wordpress
docker exec wordpress ping -c 2 mariadb
```

---

## 🐛 Debugging

### View All Logs

```bash
make logs
```

### Service-Specific Logs

```bash
docker logs nginx --tail 100
docker logs wordpress --tail 100 -f
docker logs mariadb 2>&1 | grep -i error
```

### Check Container Health

```bash
# Container status
docker ps -a

# Resource usage
docker stats

# Inspect container
docker inspect wordpress
```

### Common Issues

#### Build Cache Issues

```bash
# Clear build cache
docker builder prune -af

# Rebuild without cache
docker compose -f srcs/docker-compose.yaml build --no-cache
```

#### Volume Mount Errors

```bash
# Ensure directories exist
make dirs

# Check permissions
ls -la /home/zelbassa/data/
```

#### Port Conflicts

```bash
# Check what's using a port
sudo lsof -i :443
sudo lsof -i :3306

# Kill process using port
sudo kill $(sudo lsof -t -i :443)
```

#### Database Connection Issues

```bash
# Check if MariaDB is accepting connections
docker exec mariadb mysqladmin ping -h localhost

# Check MariaDB logs
docker logs mariadb

# Connect manually
docker exec -it mariadb mysql -u root -p
```

---

## 📝 Development Workflow

### Making Changes

1. Edit configuration or Dockerfile
2. Rebuild affected service:
   ```bash
   docker compose -f srcs/docker-compose.yaml build --no-cache <service>
   docker compose -f srcs/docker-compose.yaml up -d <service>
   ```
3. Check logs for errors:
   ```bash
   docker logs <service>
   ```

### Full Reset

```bash
make purge
docker builder prune -af
make all
```

### Testing Changes

```bash
# Test NGINX config
docker exec nginx nginx -t

# Test PHP
docker exec wordpress php -v

# Test database
docker exec mariadb mysql -u root -p -e "SHOW DATABASES;"
```

---

## 🔒 Security Notes

- All secrets are stored in `secrets/` directory
- Secrets are mounted as Docker secrets (read-only at `/run/secrets/`)
- TLS 1.2/1.3 only on NGINX
- Self-signed certificates for development
- Database not exposed externally (internal network only)

---

## 📚 References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress CLI](https://developer.wordpress.org/cli/commands/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
