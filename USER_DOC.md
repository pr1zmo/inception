# Inception - User Documentation

> **For End Users and Administrators**

This guide explains how to use and manage the Inception infrastructure stack.

---

## 📦 Services Overview

The Inception stack provides the following services:

| Service | Purpose | Access |
|---------|---------|--------|
| **WordPress** | Content management system for your website | `https://zelbassa.42.fr` |
| **Adminer** | Web-based database management interface | `https://zelbassa.42.fr:8081` |
| **Static Site** | Portfolio/resume static website | `http://localhost:8082` |
| **Uptime Kuma** | Service monitoring dashboard | `http://localhost:3001` |
| **FTP Server** | File transfer for WordPress content | `ftp://zelbassa.42.fr:21` |
| **MariaDB** | Database backend (internal only) | Not directly accessible |
| **Redis** | Caching service (internal only) | Not directly accessible |

---

## 🚀 Starting and Stopping the Project

### Start All Services

```bash
make all
```

This builds all containers and starts them in the background.

### Stop All Services

```bash
make down
```

This gracefully stops all containers without removing data.

### Restart Services

```bash
make down
make all
```

Or for a complete rebuild:

```bash
make re
```

### View Running Services

```bash
make ps
```

### View Logs

```bash
make logs
```

Press `Ctrl+C` to exit log view.

---

## 🌐 Accessing the Website

### WordPress Site

1. Open your browser
2. Navigate to `https://zelbassa.42.fr`
3. Accept the self-signed certificate warning (click "Advanced" → "Proceed")

### WordPress Admin Panel

1. Go to `https://zelbassa.42.fr/wp-admin`
2. Log in with your WordPress admin credentials:
   - **Username:** Value of `WP_ADMIN_USER` from `.env`
   - **Password:** Content of `secrets/wp_admin_password.txt`

### Adminer (Database Management)

1. Navigate to `https://zelbassa.42.fr:8081`
2. Log in with:
   - **System:** MySQL
   - **Server:** `mariadb`
   - **Username:** Value of `MYSQL_USER` from `.env`
   - **Password:** Content of `secrets/db_password.txt`
   - **Database:** Value of `MYSQL_DATABASE` from `.env`

### Uptime Kuma (Monitoring)

1. Navigate to `http://localhost:3001`
2. On first access, create an admin account
3. Add monitors for your services

### Static Site

1. Navigate to `http://localhost:8082`
2. View the static portfolio/resume page

---

## 🔐 Credentials Location

All credentials are stored securely in the `secrets/` directory:

| File | Purpose |
|------|---------|
| `secrets/db_password.txt` | MariaDB user password |
| `secrets/db_root_password.txt` | MariaDB root password |
| `secrets/wp_admin_password.txt` | WordPress admin password |
| `secrets/wp_user_password.txt` | WordPress regular user password |
| `secrets/ftp_password.txt` | FTP user password |

### View a Password

```bash
cat secrets/wp_admin_password.txt
```

### Change a Password

1. Edit the password file:
   ```bash
   nano secrets/wp_admin_password.txt
   ```

2. Rebuild the affected containers:
   ```bash
   make down
   make all
   ```

> ⚠️ **Note:** Some password changes (like WordPress) may require additional steps in the application itself.

---

## ✅ Checking Service Status

### Quick Health Check

```bash
make ps
```

All services should show `Up` status.

### Detailed Container Status

```bash
docker ps
```

### Check Individual Service Logs

```bash
# NGINX logs
docker logs nginx

# WordPress logs
docker logs wordpress

# MariaDB logs
docker logs mariadb

# Check for errors in real-time
docker logs -f nginx
```

### Test WordPress Connection

```bash
curl -k https://localhost:443
```

### Test Database Connection

```bash
docker exec mariadb mysqladmin ping -h localhost
```

Expected output: `mysqld is alive`

### Test Redis Connection

```bash
docker exec redis redis-cli ping
```

Expected output: `PONG`

---

## 📂 FTP Access

### Connect via FTP Client

Use any FTP client (FileZilla, WinSCP, etc.):

- **Host:** `zelbassa.42.fr`
- **Port:** `21`
- **Username:** Value of `FTP_USER` from `.env`
- **Password:** Content of `secrets/ftp_password.txt`
- **Protocol:** FTP (explicit TLS if available)

### Command Line FTP

```bash
ftp zelbassa.42.fr
```

---

## 🔧 Common Tasks

### Backup WordPress Data

The WordPress files are stored in `/home/zelbassa/data/wordpress/`:

```bash
sudo cp -r /home/zelbassa/data/wordpress /path/to/backup/
```

### Backup Database

```bash
docker exec mariadb mysqldump -u root -p$(cat secrets/db_root_password.txt) wordpress > backup.sql
```

### Restore Database

```bash
docker exec -i mariadb mysql -u root -p$(cat secrets/db_root_password.txt) wordpress < backup.sql
```

---

## ❓ Troubleshooting

### Website Not Loading

1. Check if containers are running: `make ps`
2. Check NGINX logs: `docker logs nginx`
3. Ensure hosts file is configured: `cat /etc/hosts | grep zelbassa`

### Database Connection Error

1. Check MariaDB status: `docker logs mariadb`
2. Verify database is ready: `docker exec mariadb mysqladmin ping -h localhost`

### Cannot Access Admin Panel

1. Verify credentials in `secrets/wp_admin_password.txt`
2. Try resetting via WP-CLI:
   ```bash
   docker exec wordpress wp user update admin --user_pass=newpassword --allow-root
   ```

### Services Won't Start

```bash
make purge
make all
```

---

## 📞 Support

For technical issues, check the logs first:

```bash
make logs
```

Then consult the developer documentation (`DEV_DOC.md`) for advanced troubleshooting.
