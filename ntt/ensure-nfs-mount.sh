#!/bin/bash

# Helper script to ensure NFS shared storage is mounted
# This should be called before any setup script that uses NFS

set -e

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

log "Ensuring NFS shared storage is mounted..."

# Check if /shared is already mounted
if mountpoint -q /shared 2>/dev/null; then
    log "✓ NFS shared storage is already mounted at /shared"
    exit 0
fi

# Check if /shared directory exists
if [ ! -d /shared ]; then
    log "Creating /shared directory..."
    mkdir -p /shared
    check_status "Create /shared directory"
fi

# Get the filestore IP - try gcloud first, fallback to known IP
FILESTORE_IP=$(gcloud filestore instances list --zone=us-central1-a --format='value(networks.ipAddresses)' --filter='name:ntt-research-fs' 2>/dev/null | head -1)
if [ -z "$FILESTORE_IP" ]; then
    log "Could not determine filestore IP via gcloud, using known IP address..."
    FILESTORE_IP="10.74.215.42"
fi
log "Using filestore IP: $FILESTORE_IP"

# Install NFS client if not already installed
if ! command -v mount.nfs >/dev/null 2>&1; then
    log "Installing NFS client..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y nfs-common >/dev/null 2>&1
    check_status "Install NFS client"
fi

# Mount the NFS share
log "Mounting NFS share from $FILESTORE_IP:/ntt_storage to /shared..."
if mount -t nfs -o nolock "$FILESTORE_IP:/ntt_storage" /shared 2>/dev/null; then
    log "✓ NFS share mounted successfully"

    # Add to fstab if not already there
    if ! grep -q "$FILESTORE_IP:/ntt_storage" /etc/fstab; then
        echo "$FILESTORE_IP:/ntt_storage /shared nfs defaults,nolock 0 0" >> /etc/fstab
        log "✓ Added NFS mount to /etc/fstab for persistence"
    fi
else
    log "⚠ Failed to mount NFS share (this may be expected in container environments)"
    log "Creating local /shared directory structure for script compatibility..."
    mkdir -p /shared/{scripts,configs,keys,logs,slurm-config}
    log "✓ Created local /shared directory structure"
fi

log "✓ NFS shared storage is ready at /shared"