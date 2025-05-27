#!/bin/bash

# Exit on error
set -e

# Ensure NFS shared storage is mounted on control machine
print_status "Ensuring NFS shared storage is mounted on control machine..."
if ! sudo ../ensure-nfs-mount.sh; then
    print_error "Failed to mount NFS shared storage on control machine"
    exit 1
fi

# Function to print status messages
print_status() {
    echo -e "\033[1;33m==>\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m==>\033[0m $1"
}

# Function to print success messages
print_success() {
    echo -e "\033[1;32m==>\033[0m $1"
}

# Generate SSH key if it doesn't exist
if [ ! -f "ood_ssh_key" ]; then
    print_status "Generating SSH key for OOD setup..."
    ssh-keygen -t rsa -b 4096 -f ood_ssh_key -N "" -q
    if [ $? -ne 0 ]; then
        print_error "Failed to generate SSH key"
        exit 1
    fi
fi

# Copy SSH key to NFS shared storage and install on OOD instance
print_status "Copying SSH key to NFS shared storage and installing on OOD instance..."
SHARED_KEYS_DIR="/shared/keys"
mkdir -p "${SHARED_KEYS_DIR}"
cp ood_ssh_key.pub "${SHARED_KEYS_DIR}/"

gcloud compute ssh ntt-research-ood-0 \
    --zone=us-central1-a \
    --command="mkdir -p ~/.ssh && chmod 700 ~/.ssh && cp /shared/keys/ood_ssh_key.pub ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" \
    --quiet

# Check if post-setup script exists
if [ ! -f "ood-post-setup.sh" ]; then
    print_error "ood-post-setup.sh not found in current directory"
    exit 1
fi

# Copy post-setup script to NFS shared storage
print_status "Copying post-setup script to NFS shared storage..."
SHARED_SCRIPTS_DIR="/shared/scripts"
mkdir -p "${SHARED_SCRIPTS_DIR}"
cp ood-post-setup.sh "${SHARED_SCRIPTS_DIR}/"
chmod +x "${SHARED_SCRIPTS_DIR}/ood-post-setup.sh"

# Execute post-setup script from NFS shared storage and capture output
print_status "Executing post-setup script from NFS shared storage..."
gcloud compute ssh ntt-research-ood-0 \
    --zone=us-central1-a \
    --command="sudo bash /shared/scripts/ood-post-setup.sh 2>&1 | tee /tmp/ood-setup.log" \
    --quiet

# Copy log file from NFS shared storage
print_status "Copying setup log from NFS shared storage..."
SHARED_LOGS_DIR="/shared/logs"
mkdir -p "${SHARED_LOGS_DIR}"
gcloud compute ssh ntt-research-ood-0 \
    --zone=us-central1-a \
    --command="sudo cp /tmp/ood-setup.log /shared/logs/" \
    --quiet
cp "${SHARED_LOGS_DIR}/ood-setup.log" ood-setup.log

# Check if setup was successful
if grep -q "error" ood-setup.log; then
    print_error "OOD post-setup encountered errors. Check ood-setup.log for details."
    exit 1
else
    print_success "OOD post-setup completed successfully"
    print_status "Setup log saved to ood-setup.log"
fi