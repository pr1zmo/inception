# Inception - Developer Documentation

> **For Developers and System Administrators**

---

## 📋 Prerequisites

- **OS:** Debian 12+
- **Docker Engine:** 24.0+
- **Docker Compose:** v2.20+
- **Make, Git:** Latest versions
- **Disk Space:** 10GB free minimum

---

## ⚙️ Quick Setup

1. **Create `.env` file** with your configuration (see `.env.example`)
2. **Generate secrets:**
   ```bash
   mkdir -p secrets
   openssl rand -base64 24 > secrets/db_password.txt
   openssl rand -base64 24 > secrets/db_root_password.txt
   ```
3. **Add to `/etc/hosts`:**
   ```bash
   echo "127.0.0.1 zelbassa.42.fr" | sudo tee -a /etc/hosts
   ```

---

## 🏗️ Building and Running

```bash
make all          # Build and start all services
make down         # Stop all containers
make clean        # Stop and remove volumes
make purge        # Full cleanup (delete everything)
make re           # Complete rebuild
make logs         # View all logs
make ps           # Show container status
```

---

## 🔧 Common Commands

```bash
# Rebuild a specific service
docker compose -f srcs/docker-compose.yaml build --no-cache wordpress
docker compose -f srcs/docker-compose.yaml up -d wordpress

# View logs for specific service
docker logs -f nginx

# Shell access
docker exec -it wordpress sh
docker exec -it mariadb sh
docker exec -it nginx sh
```

---

## 📁 Data Storage

All data persists in `/home/$USER/data/`:

```
/home/zelbassa/data/wordpress  # WordPress files, uploads
/home/zelbassa/data/mariadb    # Database files
/home/zelbassa/data/cuma       # Uptime Kuma data
```

**Backup database:**
```bash
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) --all-databases > backup.sql
```

---

## 🔧 Project Structure

```
inception/
├── Makefile
├── .env
├── secrets/              # Credentials (not in git)
└── srcs/
    ├── docker-compose.yaml
    └── requirements/
        ├── nginx/
        ├── wordpress/
        ├── mariadb/
        └── bonus/
            ├── redis/
            ├── ftp/
            ├── adminer/
            ├── static-site/
            └── cuma/
```

---

## 🌐 Services & Ports

| Service | Internal | External |
|---------|----------|----------|
| nginx | 443 | 443 |
| adminer | 8081 | 8081 |
| static-site | 8082 | 8082 |
| cuma | 3001 | 3001 |
| ftp | 21 | 21 |

All services communicate via Docker bridge network: `inception_network`

---

## 🐛 Troubleshooting

```bash
# Check container status
make ps

# View logs
make logs

# Service-specific logs
docker logs -f <service-name>

# Clear build cache
docker builder prune -af

# Full reset
make purge
make all
```

**Port conflicts:**
```bash
sudo lsof -i :<port>
sudo kill -9 <PID>
```

**Database issues:**
```bash
docker exec mariadb mysqladmin ping -h localhost
```

---

## 🔒 Security Notes

- Secrets stored in `secrets/` directory (not in git)
- Self-signed TLS certificates for development
- MariaDB not exposed externally
- All inter-service communication via internal network

---

## 📚 References

- [Docker Documentation](https://docs.docker.com/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)

