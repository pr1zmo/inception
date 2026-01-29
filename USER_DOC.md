# Inception - User Documentation

> **For End Users and Administrators**

---

## 📦 Services Overview

| Service | Purpose | Access |
|---------|---------|--------|
| **WordPress** | Content management system | `https://zelbassa.42.fr` |
| **Adminer** | Database management | `https://zelbassa.42.fr:8081` |
| **Static Site** | Portfolio website | `http://localhost:8082` |
| **Uptime Kuma** | Service monitoring | `http://localhost:3001` |
| **FTP** | File transfer | `ftp://zelbassa.42.fr` |
| **Redis** | Caching (internal) | Not accessible |
| **MariaDB** | Database (internal) | Not accessible |

---

## 🚀 Managing Services

```bash
make all           # Start all services
make down          # Stop all services
make re            # Full rebuild
make ps            # Check status
make logs          # View logs
```

---

## 🌐 Accessing Services

### WordPress

1. Open `https://zelbassa.42.fr`
2. Accept SSL certificate warning
3. Admin panel: `https://zelbassa.42.fr/wp-admin`

### Database (Adminer)

1. Go to `https://zelbassa.42.fr:8081`
2. **System:** MySQL
3. **Server:** `mariadb`
4. **Username:** From `.env` (MYSQL_USER)
5. **Password:** From `secrets/db_password.txt`

### Other Services

- **Static Site:** `http://localhost:8082`
- **Monitoring:** `http://localhost:3001`

---

## 🔐 Credentials

All passwords are in the `secrets/` directory:

```bash
cat secrets/wp_admin_password.txt      # WordPress admin
cat secrets/db_password.txt            # Database user
cat secrets/ftp_password.txt           # FTP user
```

To change a password:
```bash
nano secrets/wp_admin_password.txt     # Edit
make down && make all                  # Restart services
```

---

## 📂 FTP Access

**FTP Client Details:**
- **Host:** `zelbassa.42.fr`
- **Port:** `21`
- **Username:** From `.env` (FTP_USER)
- **Password:** From `secrets/ftp_password.txt`

**Command line:**
```bash
ftp zelbassa.42.fr
```

---

## ✅ Health Checks

```bash
# All services running?
make ps

# Website accessible?
curl -k https://localhost:443

# Database responding?
docker exec mariadb mysqladmin ping -h localhost
```

---

## 🔧 Backups

**Backup database:**
```bash
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) wordpress > backup.sql
```

**Restore database:**
```bash
docker exec -i mariadb mysql -u root -p$(cat secrets/db_root_password.txt) wordpress < backup.sql
```

---

## ❓ Common Issues

| Issue | Solution |
|-------|----------|
| Website won't load | Check `make ps` and `docker logs nginx` |
| Can't login to WordPress | Verify `secrets/wp_admin_password.txt` |
| Database errors | Check `docker logs mariadb` |
| Services won't start | Run `make purge` then `make all` |

---

## 📞 Support

Check logs first:
```bash
make logs
```

For technical details, see `DEV_DOC.md`.

