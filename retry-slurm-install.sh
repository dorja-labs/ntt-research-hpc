#!/bin/bash

# SLURM Installation Retry Script
# This script retries the SLURM installation with proper apt lock handling

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

print_status "Starting SLURM installation retry..."

# Check if we're running the retry from the control machine
if [ ! -f "ctrl.sh" ]; then
    print_error "This script should be run from the root directory of the ntt-research project"
    exit 1
fi

# Function to check SLURM cluster status
check_slurm_status() {
    print_status "Checking current SLURM cluster status..."

    local slurm_head_name="ntt-research-hpc-slurm-0"
    local slurm_compute_name="ntt-research-hpc-slurm-1"

    # Check if instances exist
    if gcloud compute instances describe "$slurm_head_name" --zone=us-central1-a --quiet >/dev/null 2>&1; then
        print_success "SLURM head node ($slurm_head_name) exists"
        HEAD_NODE_EXISTS=true
    else
        print_error "SLURM head node ($slurm_head_name) not found"
        HEAD_NODE_EXISTS=false
    fi

    if gcloud compute instances describe "$slurm_compute_name" --zone=us-central1-a --quiet >/dev/null 2>&1; then
        print_success "SLURM compute node ($slurm_compute_name) exists"
        COMPUTE_NODE_EXISTS=true
    else
        print_error "SLURM compute node ($slurm_compute_name) not found"
        COMPUTE_NODE_EXISTS=false
    fi
}

# Function to fix apt locks on a remote node
fix_apt_locks_remote() {
    local node_name=$1
    print_status "Fixing apt locks on $node_name..."

    # Commands to clear apt locks
    local cleanup_commands="
        sudo pkill -f apt-get || true;
        sudo pkill -f dpkg || true;
        sleep 2;
        sudo rm -f /var/lib/dpkg/lock-frontend;
        sudo rm -f /var/lib/apt/lists/lock;
        sudo rm -f /var/cache/apt/archives/lock;
        sudo dpkg --configure -a;
        echo 'Apt locks cleared on $node_name'
    "

    if gcloud compute ssh "$node_name" --zone=us-central1-a --command="$cleanup_commands" --quiet; then
        print_success "Apt locks cleared on $node_name"
    else
        print_error "Failed to clear apt locks on $node_name"
        return 1
    fi
}

# Function to retry SLURM setup on a node
retry_slurm_setup() {
    local node_name=$1
    local skip_controller=${2:-""}

    print_status "Retrying SLURM setup on $node_name..."

    # First, fix any apt lock issues
    fix_apt_locks_remote "$node_name"

    # Copy the updated post-setup script
    print_status "Copying updated post-setup script to $node_name..."
    gcloud compute scp "ntt/hpc-slurm/hpc-slurm-post-setup.sh" "$node_name:/tmp/hpc-slurm-post-setup.sh" --zone=us-central1-a --quiet

    # Copy SLURM config
    print_status "Copying SLURM config to $node_name..."
    gcloud compute scp "ntt/hpc-slurm/slurm.conf" "$node_name:/tmp/slurm.conf" --zone=us-central1-a --quiet

    # Get filestore IP
    local filestore_ip=""
    if filestore_ip=$(gcloud filestore instances describe ntt-research-fs --zone=us-central1-a --format='get(networks[0].ipAddresses[0])' --quiet 2>/dev/null); then
        print_status "Using filestore IP: $filestore_ip"
    else
        print_status "Warning: Could not get filestore IP, using fallback"
        filestore_ip=""
    fi

    # Execute the setup script
    print_status "Executing setup script on $node_name..."
    local env_vars="FILESTORE_IP=$filestore_ip"
    if [ -n "$skip_controller" ]; then
        env_vars="$env_vars SKIP_CONTROLLER=1"
    fi

    if gcloud compute ssh "$node_name" --zone=us-central1-a --command="sudo $env_vars bash /tmp/hpc-slurm-post-setup.sh" --quiet; then
        print_success "SLURM setup completed successfully on $node_name"
        return 0
    else
        print_error "SLURM setup failed on $node_name"
        return 1
    fi
}

# Main execution
check_slurm_status

if [ "$HEAD_NODE_EXISTS" = false ] || [ "$COMPUTE_NODE_EXISTS" = false ]; then
    print_error "SLURM cluster nodes not found. Please run './ctrl.sh create hpc-slurm' first."
    exit 1
fi

print_status "Both SLURM nodes found. Proceeding with retry..."

# Retry setup on head node
print_status "=== Retrying SLURM head node setup ==="
if retry_slurm_setup "ntt-research-hpc-slurm-0"; then
    print_success "SLURM head node setup completed"
else
    print_error "SLURM head node setup failed"
    exit 1
fi

# Retry setup on compute node
print_status "=== Retrying SLURM compute node setup ==="
if retry_slurm_setup "ntt-research-hpc-slurm-1" "1"; then
    print_success "SLURM compute node setup completed"
else
    print_error "SLURM compute node setup failed"
    exit 1
fi

# Test SLURM cluster
print_status "=== Testing SLURM cluster ==="
print_status "Testing SLURM connectivity from head node..."
if gcloud compute ssh "ntt-research-hpc-slurm-0" --zone=us-central1-a --command="sinfo && squeue" --quiet; then
    print_success "SLURM cluster is working correctly!"
else
    print_error "SLURM cluster test failed. Check the logs on the nodes."
fi

print_success "SLURM installation retry completed!"
print_status ""
print_status "Next steps:"
print_status "1. Check SLURM cluster status: gcloud compute ssh ntt-research-hpc-slurm-0 --zone=us-central1-a --command='sinfo'"
print_status "2. Submit a test job: gcloud compute ssh ntt-research-hpc-slurm-0 --zone=us-central1-a --command='srun hostname'"
print_status "3. If you have JupyterHub, it should now be able to connect to SLURM"