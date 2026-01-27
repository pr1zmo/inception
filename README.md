# Inception - Docker Infrastructure Project

> **Author:** zelbassa  
> **42 Project:** System Administration with Docker

This project sets up a complete WordPress infrastructure using Docker containers on Debian. It includes WordPress, MariaDB, Nginx with TLS, and several bonus services.

---

## 🏗️ Architecture

```
                         ┌─────────────────────────────────────────────┐
                         │              inception_network              │
                         └─────────────────────────────────────────────┘
                                              │
        ┌─────────────────────────────────────┼─────────────────────────────────────┐
        │                                     │                                     │
   ┌────▼────┐    ┌──────────┐     ┌──────────▼──────────┐    ┌──────────┐    ┌─────▼─────┐
   │  NGINX  │◄───│ WordPress│◄────│      MariaDB        │    │  Redis   │    │  Adminer  │
   │  :443   │    │  :9000   │     │       :3306         │    │  :6379   │    │  :8081    │
   └────┬────┘    └──────────┘     └─────────────────────┘    └──────────┘    └───────────┘
        │
        │         ┌──────────┐    ┌─────────────────────┐    ┌──────────┐
        └─────────│   FTP    │    │    Static Site      │    │   Cuma   │
                  │   :21    │    │       :8082         │    │  :3001   │
                  └──────────┘    └─────────────────────┘    └──────────┘
```

### Services Overview

| Service | Description | Port(s) |
|---------|-------------|---------|
| **nginx** | Reverse proxy with TLS 1.2/1.3 | 443, 8081 |
| **wordpress** | WordPress + PHP-FPM 8.2 | 9000 (internal) |
| **mariadb** | MySQL-compatible database | 3306 (internal) |
| **redis** | Object caching for WordPress | 6379 (internal) |
| **ftp** | vsftpd FTP server | 21, 21000-21010 |
| **adminer** | Database management UI | via nginx:8081 |
| **static-site** | Static website (Node.js) | 8082 |
| **cuma** | Uptime Kuma monitoring | 3001 |

---

## 📋 Prerequisites

### Fresh Debian 12 (Bookworm) Installation

#### Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

#### Step 2: Install Required Packages

```bash
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    make \
    sudo
```

#### Step 3: Install Docker

```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Step 4: Configure Docker for Non-Root User

```bash
sudo usermod -aG docker $USER
```

> ⚠️ **Important:** Log out and log back in for the group changes to take effect.

#### Step 5: Verify Installation

```bash
docker --version
docker compose version
docker buildx version  # Must be 0.17.0 or later
```

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <your-repository-url> inception
cd inception
```

### 2. Configure Environment Variables

Create/edit the `.env` file in the project root:

```env
# Domain Configuration
DOMAIN_NAME=zelbassa.42.fr

# MariaDB Configuration
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb:3306

# WordPress Admin Configuration
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@zelbassa.42.fr

# WordPress User Configuration
WP_USER=author
WP_USER_EMAIL=author@zelbassa.42.fr

# Redis Configuration
REDIS_HOST=redis:6379

# FTP Configuration
FTP_USER=ftpuser

# System User
USER=zelbassa
```

### 3. Configure Secrets

```bash
mkdir -p secrets

echo "your_db_password" > secrets/db_password.txt
echo "your_db_root_password" > secrets/db_root_password.txt
echo "your_wp_admin_password" > secrets/wp_admin_password.txt
echo "your_wp_user_password" > secrets/wp_user_password.txt
echo "your_ftp_password" > secrets/ftp_password.txt
```

> 🔒 **Security:** Never commit these files to version control.

### 4. Setup Hosts File

```bash
make setup-hosts
```

Or manually:

```bash
echo "127.0.0.1 zelbassa.42.fr" | sudo tee -a /etc/hosts
```

### 5. Build and Run

```bash
make all
```

---

## 📖 Makefile Commands

| Command | Description |
|---------|-------------|
| `make all` | Build and start all containers |
| `make down` | Stop all containers |
| `make clean` | Stop containers and remove volumes |
| `make purge` | Complete cleanup (containers, images, volumes, data) |
| `make re` | Full clean and rebuild |
| `make logs` | View container logs (follow mode) |
| `make ps` | List running containers |
| `make setup-hosts` | Add domain to /etc/hosts |
| `make exec-nginx` | Shell into nginx container |
| `make exec-wordpress` | Shell into wordpress container |
| `make exec-mariadb` | Shell into mariadb container |

---

## 🌐 Accessing Services

| Service | URL |
|---------|-----|
| **WordPress** | `https://zelbassa.42.fr` |
| **Adminer** | `https://zelbassa.42.fr:8081` |
| **Static Site** | `http://localhost:8082` |
| **Uptime Kuma** | `http://localhost:3001` |
| **FTP** | `ftp://zelbassa.42.fr:21` |

> ⚠️ The SSL certificate is self-signed. Your browser will show a security warning - this is expected.

---

## 📁 Project Structure

```
inception/
├── .env                    # Environment variables
├── Makefile                # Build and management commands
├── README.md               # This file
├── secrets/                # Password files (not in git)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── ftp_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── docker-compose.yaml
    └── requirements/
        ├── mariadb/        # MariaDB container
        ├── nginx/          # Nginx reverse proxy
        ├── wordpress/      # WordPress + PHP-FPM
        └── bonus/
            ├── adminer/    # Database admin UI
            ├── cuma/       # Uptime Kuma monitoring
            ├── ftp/        # FTP server
            ├── redis/      # Redis cache
            └── static-site/ # Static website
```

---

## 🔧 Troubleshooting

### Docker Permission Denied

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Port Already in Use

```bash
sudo lsof -i :443
sudo lsof -i :8081
```

### Check Container Logs

```bash
make logs
# Or for a specific container
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### Database Connection Issues

```bash
docker exec mariadb mysqladmin ping -h localhost
```

### Clean Restart

```bash
make purge
make all
```

---

## 📦 Quick Install Script

One-liner for fresh Debian 12:

```bash
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release git make sudo && \
sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
sudo chmod a+r /etc/apt/keyrings/docker.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
sudo apt update && \
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
sudo usermod -aG docker $USER && \
echo "Installation complete! Log out and log back in, then run 'make all'"
```

---

## ✅ Bonus Features Implemented

- [x] **Redis cache** - WordPress object caching for improved performance
- [x] **FTP server** - vsftpd for file management
- [x] **Adminer** - Database administration interface
- [x] **Static website** - Node.js powered portfolio/resume site
- [x] **Uptime Kuma** - Service monitoring dashboard

---

## 📄 License

This project is part of the 42 School curriculum.

---

**Made with ❤️ by zelbassa**
