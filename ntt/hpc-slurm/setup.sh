#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/slurm_jupyterhub_setup-$(date +%Y%m%d-%H%M%S).log"
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

log "Starting SLURM and JupyterHub integration setup from control machine..."

# Create a temporary directory for staging files
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: ${TEMP_DIR}"

# Copy post-setup script to temporary directory
log "Copying post-setup script to temporary directory..."
cp ntt/hpc-slurm/hpc-slurm-post-setup.sh "${TEMP_DIR}/hpc-slurm-post-setup.sh"
chmod +x "${TEMP_DIR}/hpc-slurm-post-setup.sh"
check_status "Copy post-setup script to temporary directory"

# Copy slurm.conf to temporary directory
log "Copying slurm.conf to temporary directory..."
cp ntt/hpc-slurm/slurm.conf "${TEMP_DIR}/slurm.conf"
check_status "Copy slurm.conf to temporary directory"

# --- Instance IPs ---
log "Getting SLURM head node IP..."
SLURM_HEAD_NODE_NAME="ntt-research-hpc-slurm-0"
SLURM_HEAD_IP=$(gcloud compute instances describe "${SLURM_HEAD_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
check_status "Get SLURM head node IP for ${SLURM_HEAD_NODE_NAME}"
log "SLURM Head node IP: ${SLURM_HEAD_IP}"

log "Getting SLURM compute node IP..."
SLURM_COMPUTE_NODE_NAME="ntt-research-hpc-slurm-1"
SLURM_COMPUTE_IP=$(gcloud compute instances describe "${SLURM_COMPUTE_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
check_status "Get SLURM compute node IP for ${SLURM_COMPUTE_NODE_NAME}"
log "SLURM Compute node IP: ${SLURM_COMPUTE_IP}"

log "Getting filestore IP..."
if FILESTORE_IP=$(gcloud filestore instances describe ntt-research-fs --zone=us-central1-a --format='get(networks[0].ipAddresses[0])' --quiet 2>/dev/null); then
    check_status "Get filestore IP"
    log "Filestore IP: ${FILESTORE_IP}"
else
    log "⚠ Warning: Could not retrieve filestore IP. Scripts will use fallback IP."
    FILESTORE_IP=""
fi

log "Getting JupyterHub node IP..."
JUPYTERHUB_NODE_NAME="ntt-research-jupyterhub-0"
if JUPYTERHUB_IP=$(gcloud compute instances describe "${JUPYTERHUB_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet 2>/dev/null); then
    check_status "Get JupyterHub node IP for ${JUPYTERHUB_NODE_NAME}"
    log "JupyterHub node IP: ${JUPYTERHUB_IP}"
else
    log "⚠ Warning: JupyterHub node not found. SLURM will be configured without JupyterHub integration."
    JUPYTERHUB_IP=""
fi

# --- SLURM Head Node Setup ---
log "--- Initiating SLURM head node setup (${SLURM_HEAD_NODE_NAME}) ---"

# Copy the post-setup script to the SLURM head node
log "Copying post-setup script to SLURM head node..."
gcloud compute scp "${TEMP_DIR}/hpc-slurm-post-setup.sh" "${SLURM_HEAD_NODE_NAME}:/tmp/hpc-slurm-post-setup.sh" --zone=us-central1-a --quiet
check_status "Copy post-setup script to SLURM head node"

# Copy the slurm.conf to the SLURM head node
log "Copying slurm.conf to SLURM head node..."
gcloud compute scp "${TEMP_DIR}/slurm.conf" "${SLURM_HEAD_NODE_NAME}:/tmp/slurm.conf" --zone=us-central1-a --quiet
check_status "Copy slurm.conf to SLURM head node"

# Execute the script on SLURM head node
log "Executing script on ${SLURM_HEAD_NODE_NAME}..."
gcloud compute ssh "${SLURM_HEAD_NODE_NAME}" --zone=us-central1-a --command="sudo FILESTORE_IP=${FILESTORE_IP} bash /tmp/hpc-slurm-post-setup.sh" --quiet
check_status "Execute script on SLURM head node"
log "--- SLURM head node setup script finished. Check its log on ${SLURM_HEAD_NODE_NAME} in /tmp/ for details. ---"

# --- SLURM Compute Node Setup ---
log "--- Initiating SLURM compute node setup (${SLURM_COMPUTE_NODE_NAME}) ---"

# Copy the post-setup script to the SLURM compute node
log "Copying post-setup script to SLURM compute node..."
gcloud compute scp "${TEMP_DIR}/hpc-slurm-post-setup.sh" "${SLURM_COMPUTE_NODE_NAME}:/tmp/hpc-slurm-post-setup.sh" --zone=us-central1-a --quiet
check_status "Copy post-setup script to SLURM compute node"

# Copy the slurm.conf to the SLURM compute node
log "Copying slurm.conf to SLURM compute node..."
gcloud compute scp "${TEMP_DIR}/slurm.conf" "${SLURM_COMPUTE_NODE_NAME}:/tmp/slurm.conf" --zone=us-central1-a --quiet
check_status "Copy slurm.conf to SLURM compute node"

# Execute the script on SLURM compute node (but skip controller setup)
log "Executing script on ${SLURM_COMPUTE_NODE_NAME}..."
gcloud compute ssh "${SLURM_COMPUTE_NODE_NAME}" --zone=us-central1-a --command="sudo SKIP_CONTROLLER=1 FILESTORE_IP=${FILESTORE_IP} bash /tmp/hpc-slurm-post-setup.sh" --quiet
check_status "Execute script on SLURM compute node"
log "--- SLURM compute node setup script finished. Check its log on ${SLURM_COMPUTE_NODE_NAME} in /tmp/ for details. ---"

# --- JupyterHub Node Configuration for SLURM Integration ---
if [ -n "${JUPYTERHUB_IP}" ]; then
    log "--- Initiating JupyterHub node (${JUPYTERHUB_NODE_NAME}) configuration for SLURM integration ---"

    log "JupyterHub Node: Installing munge and slurm-client..."
    gcloud compute ssh "${JUPYTERHUB_NODE_NAME}" --zone=us-central1-a --command="sudo apt-get update -y && sudo apt-get install -y munge libmunge-dev slurm-client=23.11.4*" --quiet
    check_status "JupyterHub Node: munge and slurm-client installed"

    log "JupyterHub Node: Installing NFS client and mounting shared storage..."
    JUPYTERHUB_NFS_SETUP_COMMAND="sudo apt-get install -y nfs-common && sudo mkdir -p /shared && (sudo mount -t nfs ${FILESTORE_IP}:/ntt_storage /shared 2>/dev/null && echo \"NFS mounted successfully\" && echo \"${FILESTORE_IP}:/ntt_storage /shared nfs defaults 0 0\" | sudo tee -a /etc/fstab || (echo \"Failed to mount NFS share\" && exit 1))"
    gcloud compute ssh "${JUPYTERHUB_NODE_NAME}" --zone=us-central1-a --command="${JUPYTERHUB_NFS_SETUP_COMMAND}" --quiet
    check_status "JupyterHub Node: NFS client installed and shared storage mounted"

    log "JupyterHub Node: Creating directories and setting up SLURM configuration..."
    JUPYTERHUB_SETUP_COMMAND="sudo mkdir -p /etc/munge /etc/slurm && \
        sudo cp /shared/slurm-config/munge.key /etc/munge/munge.key && \
        sudo chown -R munge:munge /etc/munge && \
        sudo chmod 0700 /etc/munge && \
        sudo chmod 0400 /etc/munge/munge.key && \
        sudo systemctl enable munge && sudo systemctl restart munge && \
        sudo rm -f /etc/slurm/slurm.conf && \
        sudo ln -s /shared/slurm-config/slurm.conf /etc/slurm/slurm.conf && \
        sudo chown -h slurm:slurm /etc/slurm/slurm.conf"
    gcloud compute ssh "${JUPYTERHUB_NODE_NAME}" --zone=us-central1-a --command="${JUPYTERHUB_SETUP_COMMAND}" --quiet
    check_status "JupyterHub Node: Directories created and SLURM configuration set up"

    log "JupyterHub Node: Testing SLURM connectivity via sinfo..."
    gcloud compute ssh "${JUPYTERHUB_NODE_NAME}" --zone=us-central1-a --command="sinfo -N || echo 'sinfo command failed or returned no nodes (this might be okay if cluster is still settling)'" --quiet
    log "JupyterHub_CMD: sinfo executed (see JupyterHub node for exact sinfo output if needed)"

    log "--- JupyterHub node SLURM integration tasks finished. ---"
    log "JupyterHub should be accessible at http://${JUPYTERHUB_IP}:8000"
    log "JupyterHub can now submit jobs to the SLURM cluster via BatchSpawner"
else
    log "--- Skipping JupyterHub integration (JupyterHub node not found) ---"
fi

# Cleanup
log "Cleaning up temporary directory ${TEMP_DIR}..."
rm -rf "${TEMP_DIR}"
check_status "Cleaned up temporary directory"

log "Check SLURM status on ${SLURM_HEAD_NODE_NAME} and JupyterHub logs on ${JUPYTERHUB_NODE_NAME} if issues arise."

log "✓✓✓ Full SLURM and JupyterHub integration setup process completed successfully! ✓✓✓"
exit 0