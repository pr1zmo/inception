# Inception - Docker Infrastructure Project

This project sets up a complete WordPress infrastructure using Docker containers on Debian. It includes WordPress, MariaDB, Nginx with TLS, and several bonus services.

## 🏗️ Architecture

| Service | Description | Port(s) |
|---------|-------------|---------|
| **nginx** | Reverse proxy with TLS | 443, 8081 |
| **wordpress** | WordPress + PHP-FPM | 9000 (internal) |
| **mariadb** | MySQL-compatible database | 3306 (internal) |
| **redis** | Object caching for WordPress | 6379 (internal) |
| **ftp** | FTP server for file management | 21, 21000-21010 |
| **adminer** | Database management UI | via nginx:8081 |
| **static-site** | Static website (Node.js) | 8082 |
| **cuma** | Uptime Kuma monitoring | 3001 |

---

## 📋 Prerequisites - Fresh Debian Installation

Follow these steps on a **fresh Debian 12 (Bookworm)** installation.

### Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install Required Packages

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

### Step 3: Install Docker

#### Add Docker's official GPG key:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

#### Add the Docker repository:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### Install Docker Engine and Docker Compose:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Step 4: Configure Docker for Non-Root User

To run Docker commands without `sudo`:

```bash
sudo usermod -aG docker $USER
```

> ⚠️ **Important:** Log out and log back in (or reboot) for the group changes to take effect.

```bash
# Verify Docker is running
newgrp docker
docker run hello-world
```

### Step 5: Verify Installation

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Check Docker Buildx version (must be 0.17.0 or later for compose build)
docker buildx version

# Check Make is available
make --version
```

> ⚠️ **Important:** `docker compose build` requires **buildx 0.17.0 or later**. If your version is older, update Docker or install a newer buildx:
> ```bash
> # Update Docker packages to get the latest buildx
> sudo apt update && sudo apt install -y docker-buildx-plugin
> ```
>
> If you get a dpkg error (`Sub-process /usr/bin/dpkg returned an error code (1)`), try:
> ```bash
> # Fix broken packages
> sudo apt --fix-broken install
> 
> # Or reconfigure dpkg
> sudo dpkg --configure -a
> 
> # Then retry the installation
> sudo apt update && sudo apt install -y docker-buildx-plugin
> ```

---

## 🚀 Project Setup

### Step 1: Clone the Repository

```bash
git clone <your-repository-url> inception
cd inception
```

### Step 2: Configure Environment Variables

Edit the `.env` file in the project root with your settings:

```bash
nano .env
```

Example `.env` file:

```env
# Domain Configuration
DOMAIN_NAME=yourdomain.42.fr

# MariaDB Configuration
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb:3306

# WordPress Admin Configuration
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@yourdomain.42.fr

# WordPress User Configuration (non-admin)
WP_USER=author
WP_USER_EMAIL=author@yourdomain.42.fr

# Redis Configuration
REDIS_HOST=redis:6379

# FTP Configuration
FTP_USER=ftpuser

# System User (for volume paths)
USER=your_username
```

### Step 3: Configure Secrets

Create password files in the `secrets/` directory:

```bash
# Create secrets directory if it doesn't exist
mkdir -p secrets

# Database passwords
echo "your_db_password" > secrets/db_password.txt
echo "your_db_root_password" > secrets/db_root_password.txt

# WordPress passwords
echo "your_wp_admin_password" > secrets/wp_admin_password.txt
echo "your_wp_user_password" > secrets/wp_user_password.txt

# FTP password
echo "your_ftp_password" > secrets/ftp_password.txt
```

> 🔒 **Security Note:** Never commit these files to version control. Ensure they are listed in `.gitignore`.

### Step 4: Setup Hosts File

Add your domain to the local hosts file:

```bash
make setup-hosts
```

Or manually:

```bash
echo "127.0.0.1 yourdomain.42.fr" | sudo tee -a /etc/hosts
```

### Step 5: Build and Run

```bash
make all
```

This command will:
1. Create data directories in `/home/$USER/data/`
2. Build all Docker images
3. Start all containers

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

Once the containers are running:

| Service | URL |
|---------|-----|
| **WordPress** | `https://yourdomain.42.fr` |
| **Adminer** | `https://yourdomain.42.fr:8081` |
| **Static Site** | `http://localhost:8082` |
| **Uptime Kuma** | `http://localhost:3001` |
| **FTP** | `ftp://yourdomain.42.fr:21` |

> ⚠️ The SSL certificate is self-signed. Your browser will show a security warning - this is expected for local development.

---

## 🔧 Troubleshooting

### Docker Permission Denied

If you get "permission denied" errors:

```bash
sudo usermod -aG docker $USER
newgrp docker
# Or log out and log back in
```

### Port Already in Use

Check what's using the port:

```bash
sudo lsof -i :443
sudo lsof -i :8081
```

Stop the conflicting service or change the port in `docker-compose.yaml`.

### Containers Won't Start

Check the logs:

```bash
make logs
# Or for a specific container
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### Database Connection Issues

Ensure MariaDB is healthy before WordPress tries to connect:

```bash
docker exec mariadb mysqladmin ping -h localhost
```

### Clean Restart

If things are broken, do a complete purge:

```bash
make purge
make all
```

---

## 📁 Project Structure

```
inception/
├── .env                    # Environment variables
├── Makefile               # Build and management commands
├── README.md              # This file
├── secrets/               # Password files (not in git)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── ftp_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── docker-compose.yaml
    └── requirements/
        ├── mariadb/       # MariaDB container
        ├── nginx/         # Nginx reverse proxy
        ├── wordpress/     # WordPress + PHP-FPM
        └── bonus/
            ├── adminer/   # Database admin UI
            ├── cuma/      # Uptime Kuma monitoring
            ├── ftp/       # FTP server
            ├── redis/     # Redis cache
            └── static-site/ # Static website
```

---

## 📦 Quick Install Script

For convenience, here's a one-liner to install all prerequisites on a fresh Debian 12 system:

```bash
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release git make sudo && \
sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
sudo chmod a+r /etc/apt/keyrings/docker.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
sudo apt update && \
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
sudo usermod -aG docker $USER && \
echo "Installation complete! Please log out and log back in, then run 'make all' in the project directory."
```

---

## 📝 Summary of Required Packages

| Package | Purpose |
|---------|---------|
| `ca-certificates` | SSL/TLS certificate handling |
| `curl` | Download files and Docker GPG key |
| `gnupg` | GPG key management for Docker repo |
| `lsb-release` | Detect Debian version |
| `git` | Clone the repository |
| `make` | Run Makefile commands |
| `sudo` | Administrative commands |
| `docker-ce` | Docker Engine |
| `docker-ce-cli` | Docker CLI |
| `containerd.io` | Container runtime |
| `docker-buildx-plugin` | Docker build extensions |
| `docker-compose-plugin` | Docker Compose V2 |

---

## 📄 License

This project is part of the 42 School curriculum.
