#!/bin/bash

# Docker and ALTCHA Sentinel Setup Script for Ubuntu 24.04
# For fresh installations - Creates secure non-root user and sets up everything
# Run as root: bash install-ubuntu-24.sh

set -e

# Sentinel Docker image tag
SENTINEL_VERSION="1.14.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_status "Starting complete Docker and ALTCHA setup for Ubuntu 24.04..."

# Create non-root user if it doesn't exist
USERNAME="altcha"
PASSWORD="altcha123"
if id "$USERNAME" &>/dev/null; then
    print_warning "User $USERNAME already exists"
else
    print_status "Creating user: $USERNAME"
    useradd -m -s /bin/bash "$USERNAME"
    
    # Set a temporary password and force change on first login
    echo "$USERNAME:$PASSWORD" | chpasswd
    chage -d 0 "$USERNAME"
    print_warning "User $USERNAME created with temporary password: $PASSWORD"
    print_warning "This password must be changed on first login"
fi

# Add user to sudo group
usermod -aG sudo "$USERNAME"

# Update system
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    ufw \
    fail2ban \
    unattended-upgrades \
    htop \
    nano \
    vim \
    wget \
    git

# Configure firewall
print_status "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080/tcp comment "ALTCHA Sentinel"
ufw --force enable

# Configure fail2ban
print_status "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Configure automatic security updates
print_status "Enabling automatic security updates..."
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
systemctl enable unattended-upgrades

# Add Docker's official GPG key
print_status "Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
print_status "Adding Docker repository..."
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
print_status "Updating package index with Docker repository..."
apt-get update

# Install Docker
print_status "Installing Docker Engine and Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
print_status "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Add user to docker group
usermod -aG docker "$USERNAME"

# Set up Docker daemon configuration for security
print_status "Configuring Docker daemon for security..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF
systemctl restart docker

# Create ALTCHA project directory
PROJECT_DIR="/home/$USERNAME/altcha"
print_status "Creating ALTCHA project directory at $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"

# Create docker-compose.yml
print_status "Creating docker-compose.yml..."
cat > "$PROJECT_DIR/docker-compose.yml" << EOF
services:
  altcha_sentinel:
    image: ghcr.io/altcha-org/sentinel:${SENTINEL_VERSION}
    container_name: altcha_sentinel
    restart: unless-stopped
    env_file: .env
    deploy:
      resources:
        limits:
          memory: 2G
    ports:
      - "8080:8080"
    volumes:
      - altcha_sentinel_data:/data
    healthcheck:
      test: ["CMD-SHELL", "bash -c 'echo -e \"GET / HTTP/1.0\\r\\n\\r\\n\" > /dev/tcp/127.0.0.1/8080'"]
      interval: 5s
      timeout: 5s
      retries: 3
      start_period: 5s
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp

volumes:
  altcha_sentinel_data:
    driver: local
EOF

# Create comprehensive .env file
print_status "Creating .env configuration file..."
cat > "$PROJECT_DIR/.env" << 'EOF'
# ALTCHA Sentinel ENV Configuration
# Documentation: https://altcha.org/docs/v2/sentinel/advanced/env/
EOF

# Create management scripts
print_status "Creating management scripts..."

# Start script
cat > "$PROJECT_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Starting ALTCHA Sentinel..."
docker compose up -d
echo "ALTCHA started! Check status with: ./status.sh"
EOF

# Stop script
cat > "$PROJECT_DIR/stop.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Stopping ALTCHA Sentinel..."
docker compose down
echo "ALTCHA stopped."
EOF

# Status script
cat > "$PROJECT_DIR/status.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== ALTCHA Sentinel Status ==="
docker compose ps
echo ""
echo "=== Recent Logs ==="
docker compose logs --tail=20
EOF

# Update script
cat > "$PROJECT_DIR/update.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Updating ALTCHA Sentinel..."
docker compose pull
docker compose up -d
echo "Update complete!"
EOF

# Logs script
cat > "$PROJECT_DIR/logs.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose logs -f
EOF

# Make scripts executable
chmod +x "$PROJECT_DIR"/*.sh

# Create README
cat > "$PROJECT_DIR/README.md" << 'EOF'
# ALTCHA Sentinel Setup

## Configuration

Edit `.env` file to customize settings (optional):
```bash
nano .env
```

All settings have sensible defaults. The HMAC key is generated automatically by the server.

## Management Commands

- `./start.sh` - Start ALTCHA Sentinel
- `./stop.sh` - Stop ALTCHA Sentinel  
- `./status.sh` - Check status and recent logs
- `./update.sh` - Update to latest version
- `./logs.sh` - View live logs

## First Run

1. Run: `./start.sh`
2. Access at: http://your-server-ip:8080

## Firewall

UFW is configured to allow:
- SSH (port 22)
- ALTCHA (port 8080)
EOF

# Set ownership
chown -R "$USERNAME":"$USERNAME" "$PROJECT_DIR"

print_success "Installation complete!"
echo ""
print_warning "IMPORTANT SECURITY STEPS:"
echo "1. Switch to the altcha user: su - $USERNAME"
echo "2. When prompted for 'Current password', enter: $PASSWORD"
echo "3. Set a new secure password when prompted"
echo ""
print_status "Quick start commands (as altcha user):"
echo "cd ~/altcha"
echo "./start.sh"
echo ""
print_status "Access ALTCHA at: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
print_warning "Remember to:"
echo "- Keep your system updated: sudo apt update && sudo apt upgrade"
echo "- Monitor logs regularly: ./logs.sh"
echo "- Backup your configuration and data"
echo ""
print_success "Setup complete! Switch to user 'altcha' to begin."