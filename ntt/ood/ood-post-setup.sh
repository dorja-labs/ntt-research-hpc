#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/ood-setup-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        log "✓ $1"
    else
        log "✗ $1"
        return 1
    fi
}

# Install prerequisites
log "Installing prerequisites..."
apt-get update
apt-get install -y apt-transport-https ca-certificates apache2-utils
check_status "Prerequisites installation"

# Download and install OOD repository package
log "Adding OOD repository..."
wget -O /tmp/ondemand-release-web_4.0.0-noble_all.deb https://apt.osc.edu/ondemand/4.0/ondemand-release-web_4.0.0-noble_all.deb
chmod 644 /tmp/ondemand-release-web_4.0.0-noble_all.deb
apt-get install -y /tmp/ondemand-release-web_4.0.0-noble_all.deb
check_status "OOD repository installation"

# Update package lists and install OOD
log "Installing OOD packages..."
apt-get update
apt-get install -y ondemand
check_status "OOD package installation"

# Disable default Apache site
log "Disabling default Apache site..."
a2dissite 000-default.conf || true
check_status "Disable default Apache site"

# Get the instance's external IP
EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
log "External IP: ${EXTERNAL_IP}"

# Create Linux user 'ood' if it does not exist
if ! id ood &>/dev/null; then
    log "Creating Linux user ood..."
    useradd -m -s /bin/bash ood
    echo "ood:ood" | chpasswd
    check_status "Create ood user"
else
    log "Linux user ood already exists."
fi

# Configure OOD portal
log "Configuring OOD portal..."
mkdir -p /etc/ood/config
cat << EOF > /etc/ood/config/ood_portal.yml
---
servername: ntt-research-ood.c.ntt-research.internal
port: 80
ssl: null
security_strict_transport: false
auth:
  - AuthType Basic
  - AuthName "Open OnDemand"
  - AuthUserFile /etc/ood/auth/users
  - Require valid-user

# Dashboard configuration
dashboard:
  layout: default
  title: "NTT Research Portal"
  logo: "/assets/logo.png"
  nav_items:
    - title: "Dashboard"
      url: "/pun/sys/dashboard"
    - title: "Active Jobs"
      url: "/pun/sys/activejobs"
    - title: "My Jobs"
      url: "/pun/sys/myjobs"
    - title: "Files"
      url: "/pun/sys/files"
    - title: "Interactive Apps"
      url: "/pun/sys/interactive_apps"

# File system configuration
filesystem:
  - title: "Home Directory"
    path: "/home/ood"
    type: "local"
  - title: "Shared Storage"
    path: "/mnt/ntt-research-fs"
    type: "nfs"
    mount_options: "rw,vers=4,soft,rsize=1048576,wsize=1048576"
EOF

# Set proper permissions
chown -R ood:ood /etc/ood/config
chmod -R 755 /etc/ood/config
check_status "OOD portal configuration"

# Create password file and add default user using htpasswd
log "Creating password file and adding default user..."
mkdir -p /etc/ood/auth
htpasswd -cb /etc/ood/auth/users ood ood
chown -R www-data:www-data /etc/ood/auth
chmod 640 /etc/ood/auth/users
check_status "Create password file"

# Create necessary directories for OOD
log "Creating OOD directories..."
mkdir -p /var/www/ood/apps/sys/{dashboard,activejobs,myjobs,files,interactive_apps}
chown -R ood:ood /var/www/ood
chmod -R 755 /var/www/ood
check_status "Setup OOD directories"

# Create shared storage mount point
log "Creating shared storage mount point..."
mkdir -p /mnt/ntt-research-fs
chown ood:ood /mnt/ntt-research-fs
check_status "Create shared storage mount point"

# Update OOD portal configuration
log "Updating OOD portal configuration..."
/opt/ood/ood-portal-generator/sbin/update_ood_portal
check_status "Update OOD portal configuration"

# Ensure Apache modules are enabled
log "Enabling required Apache modules..."
a2enmod rewrite
a2enmod headers
a2enmod proxy
a2enmod proxy_http
a2enmod ssl
check_status "Enable Apache modules"

# Ensure OOD Apache configuration is enabled
log "Enabling OOD Apache configuration..."
if [ -f /etc/apache2/sites-available/ood-portal.conf ]; then
    a2ensite ood-portal.conf
    check_status "Enable OOD Apache site"
else
    log "✗ OOD Apache configuration not found"
    exit 1
fi

# Function to verify service is active
verify_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    local wait_time=10

    echo "Waiting for $service service to be active..."
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet $service; then
            echo "✓ $service service is active"
            return 0
        fi
        echo "Attempt $attempt: $service service not ready yet..."
        sleep $wait_time
        attempt=$((attempt + 1))
    done
    echo "✗ $service service failed to start after $max_attempts attempts"
    return 1
}

# Start Apache service
echo 'Starting Apache service...'
systemctl enable apache2
systemctl restart apache2
check_status "Start Apache service"

# Wait for Apache service to be active
verify_service "apache2"

# Check Apache configuration
log "Checking Apache configuration..."
apache2ctl -t
check_status "Apache configuration test"

# Check enabled Apache sites
log "Checking enabled Apache sites..."
apache2ctl -S
check_status "List Apache sites"

# Final OOD portal update and Apache restart
log "Performing final OOD portal update..."
/opt/ood/ood-portal-generator/sbin/update_ood_portal
check_status "Final OOD portal update"

log "Performing final Apache restart..."
systemctl restart apache2
check_status "Final Apache restart"

# Verify OOD portal is accessible
echo 'Verifying OOD portal accessibility...'
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if curl -s -f -o /dev/null http://localhost; then
        echo "✓ OOD portal is accessible"
        break
    fi
    echo "Attempt $attempt: OOD portal not ready yet..."
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "✗ OOD portal failed to become accessible after $max_attempts attempts"
    exit 1
fi

# Verify installation
log "Verifying installation..."
if id ood &>/dev/null; then
    log "✓ User ood exists"
else
    log "✗ User ood does not exist"
fi

if systemctl is-active --quiet apache2; then
    log "✓ Apache service is active"
else
    log "✗ Apache service is not active"
fi

# Output final status
log "=== Installation Status ==="
log "OOD User: $(id ood 2>/dev/null || echo 'Not found')"
log "Apache Status: $(systemctl is-active apache2)"
log "External IP: ${EXTERNAL_IP}"
log "OOD Portal Config: $(cat /etc/ood/config/ood_portal.yml)"
log "Apache Sites: $(apache2ctl -S)"
log "Log file: $LOG_FILE"