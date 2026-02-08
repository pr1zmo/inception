*This project has been created as part of the 42 curriculum by zelbassa.*

# Inception - Docker Infrastructure Project

---

## Description

Inception is a system administration project from the 42 curriculum. The goal is to set up a small infrastructure composed of multiple Docker containers, orchestrated with Docker Compose, on a Debian-based virtual machine.

The infrastructure hosts a fully functional WordPress website backed by a MariaDB database, served through an Nginx reverse proxy with TLS encryption (TLSv1.2/TLSv1.3). Each service runs in its own dedicated container, built from custom Dockerfiles based on the penultimate stable version of Debian. No pre-built Docker images are pulled from Docker Hub (except the base OS image).

### Architecture

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

### Services

| Service | Description | Port(s) |
|---------|-------------|---------|
| **nginx** | Reverse proxy with TLS 1.2/1.3 | 443, 8081 |
| **wordpress** | WordPress + PHP-FPM 8.2 | 9000 (internal) |
| **mariadb** | MySQL-compatible database | 3306 (internal) |
| **redis** *(bonus)* | Object caching for WordPress | 6379 (internal) |
| **ftp** *(bonus)* | vsftpd FTP server | 21, 21000-21010 |
| **adminer** *(bonus)* | Database management UI | via nginx:8081 |
| **static-site** *(bonus)* | Static website (Node.js) | 8082 |
| **cuma** *(bonus)* | Uptime Kuma monitoring | 3001 |

---

## Instructions

### Prerequisites

- Debian 12 (Bookworm) or compatible Linux distribution
- Docker Engine and Docker Compose plugin installed
- `make`, `git`

#### Install Docker (Debian 12)

```bash
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release git make

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
# Log out and back in for the group change to take effect
```

### Installation and Execution

**1. Clone and enter the repository:**

```bash
git clone <your-repository-url> inception
cd inception
```

**2. Create the `.env` file** in the project root:

```env
DOMAIN_NAME=zelbassa.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb:3306
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@zelbassa.42.fr
WP_USER=author
WP_USER_EMAIL=author@zelbassa.42.fr
REDIS_HOST=redis:6379
FTP_USER=ftpuser
USER=zelbassa
```

**3. Create secrets** (passwords stored as files, never committed):

```bash
mkdir -p secrets
echo "your_db_password"       > secrets/db_password.txt
echo "your_db_root_password"  > secrets/db_root_password.txt
echo "your_wp_admin_password" > secrets/wp_admin_password.txt
echo "your_wp_user_password"  > secrets/wp_user_password.txt
echo "your_ftp_password"      > secrets/ftp_password.txt
```

**4. Add the domain to `/etc/hosts`:**

```bash
echo "127.0.0.1 zelbassa.42.fr" | sudo tee -a /etc/hosts
```

**5. Build and start:**

```bash
make all      # Mandatory services only
make bonus    # Include bonus services
```

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make all` | Build and start all mandatory containers |
| `make bonus` | Build and start all containers including bonus services |
| `make dirs` | Create required data directories |
| `make clean` | Remove unused images and volumes |
| `make fclean` | Stop everything, remove all images and volumes |
| `make re` | Full clean and rebuild |
| `make logs` | View container logs (follow mode) |

### Accessing Services

| Service | URL |
|---------|-----|
| **WordPress** | `https://zelbassa.42.fr` |
| **Adminer** | `https://zelbassa.42.fr:8081` |
| **Static Site** | `http://localhost:8082` |
| **Uptime Kuma** | `http://localhost:3001` |
| **FTP** | `ftp://zelbassa.42.fr:21` |

> The SSL certificate is self-signed; your browser will show a security warning.

---

## Project Description

### Use of Docker

Docker is used to containerize every service in the infrastructure. Each service (Nginx, WordPress, MariaDB, etc.) runs in its own isolated container, built from a custom Dockerfile based on a Debian image. Docker Compose orchestrates all containers, defining networks, volumes, dependencies, and environment configuration in a single `docker-compose.yaml` file. This approach guarantees reproducible builds and clean separation of concerns.

### Sources Included

Each service has its own directory under `srcs/requirements/` containing:
- A **Dockerfile** that builds the image from the penultimate stable Debian.
- A **tools/** directory with entrypoint/setup scripts (e.g., `setup-wordpress.sh`, `init-db.sh`).
- A **conf/** directory (where applicable) with service-specific configuration files (e.g., `nginx.conf`, `vsftpd.conf`).

### Design Choices

- **One process per container** — each container runs a single service, following Docker best practices.
- **No pre-built application images** — all images are built from scratch using only the base Debian image.
- **TLS termination at Nginx** — only Nginx exposes ports to the host; all inter-service communication happens over the internal Docker network.
- **Secrets for sensitive data** — passwords are stored in files under `secrets/` and mounted via Docker secrets, never baked into images or passed as build arguments.
- **Automatic restarts** — all services use `restart: always` to recover from crashes.

### Virtual Machines vs Docker

| Aspect | Virtual Machine | Docker Container |
|--------|----------------|-----------------|
| **Isolation** | Full hardware-level isolation via hypervisor | Process-level isolation via namespaces and cgroups |
| **Overhead** | Runs a complete guest OS; high memory/CPU cost | Shares the host kernel; minimal overhead |
| **Startup** | Minutes (full OS boot) | Seconds (process start) |
| **Portability** | VM images are large and hypervisor-specific | Images are lightweight and run anywhere Docker is installed |
| **Use case** | Running different OS kernels, strong security boundaries | Microservices, reproducible environments, CI/CD |

Docker was chosen because the project requires lightweight, reproducible service isolation rather than full OS-level separation.

### Secrets vs Environment Variables

| Aspect | Docker Secrets | Environment Variables |
|--------|---------------|----------------------|
| **Storage** | Stored as files on disk; mounted read-only into containers at `/run/secrets/` | Passed in plaintext via the process environment |
| **Visibility** | Not visible in `docker inspect`, logs, or process listings | Visible in `docker inspect`, `/proc/*/environ`, and child processes |
| **Scope** | Accessible only to services explicitly granted access | Inherited by every child process |
| **Use case** | Passwords, API keys, certificates | Non-sensitive configuration (hostnames, feature flags) |

This project uses Docker secrets for all passwords and environment variables (via `.env`) for non-sensitive configuration such as domain names and usernames.

### Docker Network vs Host Network

| Aspect | Docker Bridge Network | Host Network |
|--------|----------------------|-------------|
| **Isolation** | Containers get their own network namespace; port mapping required | Container shares the host's network stack directly |
| **Security** | Services are only reachable if explicitly published | All container ports are exposed on the host |
| **Service discovery** | Containers resolve each other by container name (DNS) | Must use `localhost`; no automatic DNS |
| **Use case** | Multi-service projects needing controlled exposure | Performance-critical workloads needing zero network overhead |

This project uses a user-defined bridge network (`inception_network`) so that services can communicate by name (e.g., `wordpress` reaches `mariadb` via hostname) while only Nginx exposes ports to the outside.

### Docker Volumes vs Bind Mounts

| Aspect | Docker Volumes | Bind Mounts |
|--------|---------------|-------------|
| **Management** | Managed by Docker; stored in `/var/lib/docker/volumes/` | Maps an arbitrary host directory into the container |
| **Portability** | Abstracted from host filesystem layout | Tied to a specific host path |
| **Performance** | Optimized by Docker's storage drivers | Native filesystem performance |
| **Backup** | Requires `docker volume` commands or direct access | Standard filesystem tools |
| **Use case** | Database storage, named data that should survive container recreation | Development mounts, config files, sharing specific host directories |

This project uses bind mounts (configured via `driver_opts` in `docker-compose.yaml`) that point to `/home/$USER/data/<service>`, meeting the 42 project requirement that volumes reside in the user's home directory.

---

## Project Structure

```
inception/
├── .env                        # Non-sensitive environment variables
├── Makefile                    # Build and management commands
├── README.md                   # This file
├── secrets/                    # Password files (not in git)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── ftp_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── docker-compose.yaml     # Service orchestration
    └── requirements/
        ├── mariadb/            # MariaDB database
        ├── nginx/              # Nginx reverse proxy + TLS
        ├── wordpress/          # WordPress + PHP-FPM
        └── bonus/
            ├── adminer/        # Database admin UI
            ├── cuma/           # Uptime Kuma monitoring
            ├── ftp/            # vsftpd FTP server
            ├── redis/          # Redis object cache
            └── static-site/    # Static Node.js website
```

---

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [WordPress CLI (WP-CLI)](https://developer.wordpress.org/cli/commands/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [vsftpd Configuration](https://security.appspot.com/vsftpd/vsftpd_conf.html)
- [Redis Documentation](https://redis.io/docs/)

### AI Usage

AI tools (GitHub Copilot) were used during this project for:
- Generating boilerplate Dockerfile and configuration templates, which were then reviewed and adapted.
- Debugging container networking and service configuration issues.
- Drafting documentation and README content.

All AI-generated code was manually reviewed, tested, and modified to fit the project requirements. No AI tool was used to design the overall architecture or make design decisions.
