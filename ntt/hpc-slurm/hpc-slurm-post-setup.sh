#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/slurm_post_setup-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check command status
check_status() {
    local message=$1
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "✓ $message"
    else
        log "✗ $message (Failed with exit code: $exit_code)"
        exit $exit_code
    fi
}

log "Starting SLURM post-setup configuration..."

# --- Package Installation ---
log "Installing required packages..."
apt-get update -y

# Install SLURM and dependencies (using native Ubuntu 24.04 packages)
apt-get install -y nfs-common munge libmunge-dev slurm-wlm=23.11.4* slurm-client=23.11.4* slurm-wlm-basic-plugins mailutils
check_status "Install required packages"

# --- NFS Setup ---
log "Setting up NFS mount..."
mkdir -p /shared

# Check if NFS is already mounted
if mountpoint -q /shared; then
    log "NFS share already mounted"
else
    log "Mounting NFS share..."
    # Use dynamic filestore IP if provided, otherwise fall back to hardcoded IP
    NFS_IP="${FILESTORE_IP:-10.74.215.42}"
    log "Using NFS IP: ${NFS_IP}"
    mount -t nfs ${NFS_IP}:/ntt_storage /shared
    check_status "Mount NFS share"

    # Add NFS mount to fstab for persistence
    if ! grep -q "${NFS_IP}:/ntt_storage /shared" /etc/fstab; then
        echo "${NFS_IP}:/ntt_storage /shared nfs defaults 0 0" >> /etc/fstab
        check_status "Add NFS mount to fstab"
    fi
fi

# --- SLURM Configuration ---
log "Creating SLURM configuration directory..."
mkdir -p /shared/slurm-config
check_status "Create SLURM config directory"

# Create SLURM directories
log "Creating SLURM directories..."
mkdir -p /etc/slurm
mkdir -p /var/log/slurm-llnl
mkdir -p /var/lib/slurm-llnl/slurmctld
mkdir -p /var/lib/slurm-llnl/slurmd
mkdir -p /var/run/slurm-llnl
mkdir -p /var/spool/slurm/ctld
mkdir -p /var/spool/slurm/d
chown -R slurm:slurm /var/lib/slurm-llnl
chown -R slurm:slurm /var/log/slurm-llnl
chown -R slurm:slurm /var/run/slurm-llnl
chown -R slurm:slurm /var/spool/slurm
chmod -R 755 /var/log/slurm-llnl
chmod -R 755 /var/spool/slurm
check_status "Create SLURM directories"

# Copy SLURM configuration to shared storage
log "Copying SLURM configuration to shared storage..."
cp /tmp/slurm.conf /shared/slurm-config/
chown slurm:slurm /shared/slurm-config/slurm.conf
chmod 644 /shared/slurm-config/slurm.conf
check_status "Copy SLURM configuration"

# Install SLURM configuration to /etc/slurm/
log "Installing SLURM configuration to /etc/slurm/..."
cp /tmp/slurm.conf /etc/slurm/slurm.conf
chown slurm:slurm /etc/slurm/slurm.conf
chmod 644 /etc/slurm/slurm.conf
check_status "Install SLURM configuration"

# Create symbolic link to shared SLURM configuration
log "Creating symbolic link to shared SLURM configuration..."
rm -f /etc/slurm/slurm.conf
ln -s /shared/slurm-config/slurm.conf /etc/slurm/slurm.conf
check_status "Create SLURM config symlink"

# --- Munge Setup ---
log "Setting up munge..."
# Generate munge key if it doesn't exist in shared storage
if [ ! -f /shared/slurm-config/munge.key ]; then
    log "Generating new munge key..."
    dd if=/dev/urandom bs=1 count=1024 > /shared/slurm-config/munge.key
    chmod 400 /shared/slurm-config/munge.key
    chown munge:munge /shared/slurm-config/munge.key
    check_status "Generate munge key"
fi

# Copy munge key to local system
log "Installing munge key..."
cp /shared/slurm-config/munge.key /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
check_status "Install munge key"

# Start munge service
log "Starting munge service..."
systemctl enable munge
systemctl restart munge
check_status "Start munge service"

# --- SLURM Service Setup ---
log "Starting SLURM services..."

# Stop services if they're running
systemctl stop slurmd slurmctld 2>/dev/null || true

# Ensure environment variables are set
cat > /etc/default/slurmctld << 'EOF'
SLURMCTLD_OPTIONS=""
EOF

cat > /etc/default/slurmd << 'EOF'
SLURMD_OPTIONS=""
EOF

# Check if this is a compute node (SKIP_CONTROLLER is set)
if [ "${SKIP_CONTROLLER}" = "1" ]; then
    log "This is a compute node - only starting slurmd service..."

    # Only start slurmd on compute nodes
    log "Starting slurmd..."
    systemctl enable slurmd
    systemctl start slurmd
    check_status "Start slurmd service"

    # Verify slurmd is running
    log "Verifying slurmd service..."
    systemctl status slurmd
    check_status "Verify slurmd service"

else
    log "This is the head node - starting both slurmctld and slurmd services..."

    # Start services in correct order
    log "Starting slurmctld..."
    systemctl enable slurmctld
    systemctl start slurmctld
    check_status "Start slurmctld service"

    # Wait for controller to be ready
    sleep 5

    log "Starting slurmd..."
    systemctl enable slurmd
    systemctl start slurmd
    check_status "Start slurmd service"

    # Verify services are running
    log "Verifying SLURM services..."
    systemctl status slurmctld slurmd
    check_status "Verify SLURM services"
fi

log "✓✓✓ SLURM post-setup configuration completed successfully! ✓✓✓"
exit 0