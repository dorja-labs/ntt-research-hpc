#!/bin/bash

# JupyterHub SLURM Integration Script
# This script configures SLURM client access on the JupyterHub node
# for BatchSpawner integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$1 failed"
        exit 1
    fi
}

print_status "Starting JupyterHub SLURM integration..."

# Get the SLURM head node IP
SLURM_HEAD_IP=$(gcloud compute instances describe ntt-research-hpc-slurm-0 --zone=us-central1-a --format="get(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")

if [ -z "$SLURM_HEAD_IP" ]; then
    print_error "Could not find SLURM head node. Make sure SLURM cluster is deployed first."
    exit 1
fi

print_status "Found SLURM head node at IP: $SLURM_HEAD_IP"

# Get filestore IP
FILESTORE_IP=$(gcloud filestore instances describe ntt-research-fs --zone=us-central1-a --format='get(networks[0].ipAddresses[0])' --quiet 2>/dev/null || echo "")

if [ -z "$FILESTORE_IP" ]; then
    print_error "Could not find filestore. Make sure storage is deployed first."
    exit 1
fi

print_status "Found filestore at IP: $FILESTORE_IP"

# Configure SLURM client on JupyterHub node
print_status "Configuring SLURM client on JupyterHub node..."

# Install SLURM client and MUNGE
print_status "Installing SLURM client and MUNGE..."
apt-get update -y
apt-get install -y munge libmunge-dev slurm-client=23.11.4*
check_status "SLURM client and MUNGE installation"

# Install NFS client if not already installed
print_status "Installing NFS client..."
apt-get install -y nfs-common
check_status "NFS client installation"

# Create mount point and mount shared storage
print_status "Setting up shared storage..."
mkdir -p /shared

# Mount the NFS share
if mount -t nfs ${FILESTORE_IP}:/ntt_storage /shared 2>/dev/null; then
    print_success "NFS share mounted successfully"
    echo "${FILESTORE_IP}:/ntt_storage /shared nfs defaults 0 0" >> /etc/fstab
else
    print_error "Failed to mount NFS share"
    exit 1
fi

# Wait for SLURM configuration files to be available
print_status "Waiting for SLURM configuration files..."
SHARED_SLURM_CONF="/shared/slurm-config/slurm.conf"
SHARED_MUNGE_KEY="/shared/slurm-config/munge.key"
MAX_WAIT_SECONDS=300 # Wait up to 5 minutes
WAIT_INTERVAL=10
ELAPSED_WAIT=0

while [ ! -f "$SHARED_SLURM_CONF" ] || [ ! -f "$SHARED_MUNGE_KEY" ]; do
    if [ $ELAPSED_WAIT -ge $MAX_WAIT_SECONDS ]; then
        print_error "SLURM config files not found after ${MAX_WAIT_SECONDS} seconds"
        exit 1
    fi
    sleep $WAIT_INTERVAL
    ((ELAPSED_WAIT += WAIT_INTERVAL))
    print_status "Waited ${ELAPSED_WAIT}s for SLURM configs..."
done

print_success "SLURM configuration files found"

# Set up MUNGE authentication
print_status "Setting up MUNGE authentication..."
mkdir -p /etc/munge
cp "$SHARED_MUNGE_KEY" /etc/munge/munge.key
chown -R munge:munge /etc/munge
chmod 0700 /etc/munge
chmod 0400 /etc/munge/munge.key
check_status "MUNGE key setup"

# Start MUNGE service
print_status "Starting MUNGE service..."
systemctl enable munge
systemctl restart munge
systemctl is-active --quiet munge
check_status "MUNGE service start"

# Set up SLURM configuration
print_status "Setting up SLURM configuration..."
mkdir -p /etc/slurm
rm -f /etc/slurm/slurm.conf
ln -s "$SHARED_SLURM_CONF" /etc/slurm/slurm.conf
chown -h slurm:slurm /etc/slurm/slurm.conf
check_status "SLURM configuration setup"

# Test SLURM connectivity
print_status "Testing SLURM connectivity..."
if sinfo -N >/dev/null 2>&1; then
    print_success "SLURM cluster is accessible"
    sinfo
else
    print_error "SLURM cluster is not accessible yet (this might be normal if cluster is still starting)"
fi

# Create JupyterHub log directory on shared storage
print_status "Creating JupyterHub directories on shared storage..."
mkdir -p /shared/jupyterhub-logs
mkdir -p /shared/notebooks
chmod 755 /shared/jupyterhub-logs
chmod 755 /shared/notebooks
check_status "JupyterHub directories creation"

print_success "JupyterHub SLURM integration completed successfully!"
print_status "JupyterHub can now submit jobs to SLURM cluster via BatchSpawner"
print_status "SLURM cluster status:"
sinfo || echo "SLURM cluster not ready yet"