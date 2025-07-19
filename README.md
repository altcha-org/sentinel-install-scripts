# ALTCHA Sentinel Auto-Installer for Ubuntu 24.04

This repository provides an automated setup script to install and configure [ALTCHA Sentinel](https://altcha.org/docs/v2/sentinel/) on Ubuntu 24.04 using Docker. The script includes system hardening, user creation, firewall configuration, and helper scripts to manage the Sentinel service.

[Docker Compose Guide](https://altcha.org/docs/v2/sentinel/install/docker-compose)

## Features

- Creates a non-root `altcha` user
- Installs Docker and Docker Compose
- Configures UFW firewall and fail2ban
- Pulls and runs `ghcr.io/altcha-org/sentinel` via Docker Compose
- Provides ready-to-use management scripts
- Enables automatic security updates and basic hardening

## Prerequisites

- Ubuntu 24.04 (fresh or minimal installation)
- You must run the script as root

## Installation

Run the installer:

```sh
bash <(curl -s https://raw.githubusercontent.com/altcha-org/sentinel-install-scripts/main/install-ubuntu-24-04.sh)
```

Or download and run:

```bash
curl -O https://raw.githubusercontent.com/altcha-org/sentinel-install-scripts/main/install-ubuntu-24-04.sh
chmod +x install-ubuntu-24-04.sh
sudo bash install-ubuntu-24-04.sh
````

This will:

* Create a user `altcha` with a temporary password `altcha123`
* Install Docker and Docker Compose
* Set up ALTCHA Sentinel in `/home/altcha/altcha/`
* Enable the firewall and basic security tools

## Post-Installation Steps

Change the default password for the `altcha` user:

```bash
su - altcha
# Follow the prompt to change your password
```

## Directory Layout

```bash
/home/altcha/altcha/
├── .env                # ALTCHA configuration (optional)
├── docker-compose.yml  # Docker Compose configuration
├── start.sh            # Start Sentinel
├── stop.sh             # Stop Sentinel
├── status.sh           # Check container status and logs
├── update.sh           # Pull latest Sentinel image and restart
└── logs.sh             # View live logs
```

## Management Commands

Run these as the `altcha` user from `/home/altcha/altcha`:

```bash
./start.sh     # Start ALTCHA Sentinel
./stop.sh      # Stop ALTCHA Sentinel
./status.sh    # Show status and recent logs
./update.sh    # Pull and restart with latest version
./logs.sh      # Tail logs
```

## Accessing ALTCHA

Once started, ALTCHA Sentinel is accessible at:

```
http://your-server-ip:8080
```

## Firewall Configuration

The installer configures the firewall (UFW) with the following rules:

* Allow SSH (port 22)
* Allow ALTCHA Sentinel (port 8080)
* Deny all other incoming connections

## Security Hardening

The script enables:

* UFW firewall
* Fail2ban for SSH protection
* Unattended security updates
* Docker daemon logging and live-restore settings

## Updating Sentinel

To update to a different version:

1. Edit `docker-compose.yml`:

```yaml
image: ghcr.io/altcha-org/sentinel:<version>
```

2. Run:

```bash
./update.sh
```

## License

MIT

## Further Resources

* [ALTCHA Project](https://altcha.org)
* [Docker Compose Guide](https://altcha.org/docs/v2/sentinel/install/docker-compose)
* [Sentinel Documentation](https://altcha.org/docs/v2/sentinel/)
