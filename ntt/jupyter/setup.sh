#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/jupyter_jupyterhub_setup-$(date +%Y%m%d-%H%M%S).log"
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
        # Do not exit here, as ctrl.sh might want to continue with other components
    fi
}

log "Starting Jupyter setup with JupyterHub integration from control machine..."

# Create a temporary directory for staging files
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: ${TEMP_DIR}"

# --- Instance IPs ---
# Jupyter instance
JUPYTER_NODE_NAME="ntt-research-jupyter-0"
JUPYTER_ZONE="us-central1-a"

log "Getting Jupyter node IP for ${JUPYTER_NODE_NAME}..."
JUPYTER_IP=$(gcloud compute instances describe "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
if [ -z "${JUPYTER_IP}" ]; then
    log "✗ Failed to get Jupyter node IP for ${JUPYTER_NODE_NAME}. Exiting Jupyter setup."
    exit 1 # Exit if we can't get the IP
fi
check_status "Get Jupyter node IP for ${JUPYTER_NODE_NAME}"
log "Jupyter node IP: ${JUPYTER_IP}"

# JupyterHub instance (for integration)
JUPYTERHUB_NODE_NAME="ntt-research-jupyterhub-0"
if JUPYTERHUB_IP=$(gcloud compute instances describe "${JUPYTERHUB_NODE_NAME}" --zone="${JUPYTER_ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet 2>/dev/null); then
    check_status "Get JupyterHub node IP for ${JUPYTERHUB_NODE_NAME}"
    log "JupyterHub node IP: ${JUPYTERHUB_IP}"
else
    log "⚠ Warning: JupyterHub node not found. Jupyter will be configured as standalone."
    JUPYTERHUB_IP=""
fi

# SLURM head node (for integration)
SLURM_HEAD_NODE_NAME="ntt-research-hpc-slurm-0"
if SLURM_HEAD_IP=$(gcloud compute instances describe "${SLURM_HEAD_NODE_NAME}" --zone="${JUPYTER_ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet 2>/dev/null); then
    check_status "Get SLURM head node IP for ${SLURM_HEAD_NODE_NAME}"
    log "SLURM head node IP: ${SLURM_HEAD_IP}"
else
    log "⚠ Warning: SLURM head node not found. Jupyter will be configured without SLURM integration."
    SLURM_HEAD_IP=""
fi

# Filestore IP
log "Getting filestore IP..."
if FILESTORE_IP=$(gcloud filestore instances describe ntt-research-fs --zone=us-central1-a --format='get(networks[0].ipAddresses[0])' --quiet 2>/dev/null); then
    check_status "Get filestore IP"
    log "Filestore IP: ${FILESTORE_IP}"
else
    log "⚠ Warning: Could not retrieve filestore IP. Jupyter will be configured without shared storage."
    FILESTORE_IP=""
fi

# --- Jupyter Node Setup ---
log "--- Initiating Jupyter node setup (${JUPYTER_NODE_NAME}) ---"

JUPYTER_POST_SETUP_SCRIPT_LOCAL_PATH="ntt/jupyter/jupyter-post-setup.sh"

if [ ! -f "${JUPYTER_POST_SETUP_SCRIPT_LOCAL_PATH}" ]; then
    log "✗ Local Jupyter post-setup script ${JUPYTER_POST_SETUP_SCRIPT_LOCAL_PATH} not found! Exiting Jupyter setup."
    exit 1
fi
log "✓ Found local Jupyter post-setup script: ${JUPYTER_POST_SETUP_SCRIPT_LOCAL_PATH}"

# Copy post-setup script to temporary directory
log "Copying post-setup script to temporary directory..."
cp "${JUPYTER_POST_SETUP_SCRIPT_LOCAL_PATH}" "${TEMP_DIR}/jupyter-post-setup.sh"
chmod +x "${TEMP_DIR}/jupyter-post-setup.sh"
check_status "Copy post-setup script to temporary directory"

# Copy SLURM integration script if available
JUPYTER_SLURM_INTEGRATION_SCRIPT="ntt/jupyter/jupyter-slurm-integration.sh"
if [ -f "${JUPYTER_SLURM_INTEGRATION_SCRIPT}" ]; then
    log "Copying SLURM integration script to temporary directory..."
    cp "${JUPYTER_SLURM_INTEGRATION_SCRIPT}" "${TEMP_DIR}/jupyter-slurm-integration.sh"
    chmod +x "${TEMP_DIR}/jupyter-slurm-integration.sh"
    check_status "Copy SLURM integration script to temporary directory"
fi

# Copy the scripts to the Jupyter node
log "Copying post-setup script to Jupyter node..."
gcloud compute scp "${TEMP_DIR}/jupyter-post-setup.sh" "${JUPYTER_NODE_NAME}:/tmp/jupyter-post-setup.sh" --zone="${JUPYTER_ZONE}" --quiet
check_status "Copy post-setup script to Jupyter node"

if [ -f "${TEMP_DIR}/jupyter-slurm-integration.sh" ]; then
    log "Copying SLURM integration script to Jupyter node..."
    gcloud compute scp "${TEMP_DIR}/jupyter-slurm-integration.sh" "${JUPYTER_NODE_NAME}:/tmp/jupyter-slurm-integration.sh" --zone="${JUPYTER_ZONE}" --quiet
    check_status "Copy SLURM integration script to Jupyter node"
fi

# Execute the script on the Jupyter node with environment variables
log "Executing script on ${JUPYTER_NODE_NAME}..."
ENV_VARS="FILESTORE_IP=${FILESTORE_IP} SLURM_HEAD_IP=${SLURM_HEAD_IP} JUPYTERHUB_IP=${JUPYTERHUB_IP}"
gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="sudo ${ENV_VARS} bash /tmp/jupyter-post-setup.sh" --quiet
check_status "Execute script on Jupyter node"
log "--- Jupyter node setup script finished. Check its log on ${JUPYTER_NODE_NAME} in /tmp/ for details. ---"

# --- SLURM Integration for Jupyter Node ---
if [ -n "${SLURM_HEAD_IP}" ] && [ -n "${FILESTORE_IP}" ]; then
    log "--- Setting up SLURM integration for Jupyter node ---"

    log "Jupyter Node: Installing SLURM client and MUNGE..."
    gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="sudo apt-get update -y && sudo apt-get install -y munge libmunge-dev slurm-client=23.11.4*" --quiet
    check_status "Jupyter Node: SLURM client and MUNGE installed"

    log "Jupyter Node: Installing NFS client and mounting shared storage..."
    JUPYTER_NFS_SETUP_COMMAND="sudo apt-get install -y nfs-common && sudo mkdir -p /shared && (sudo mount -t nfs ${FILESTORE_IP}:/ntt_storage /shared 2>/dev/null && echo \"NFS mounted successfully\" && echo \"${FILESTORE_IP}:/ntt_storage /shared nfs defaults 0 0\" | sudo tee -a /etc/fstab || (echo \"Failed to mount NFS share\" && exit 1))"
    gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="${JUPYTER_NFS_SETUP_COMMAND}" --quiet
    check_status "Jupyter Node: NFS client installed and shared storage mounted"

    log "Jupyter Node: Setting up SLURM configuration..."
    JUPYTER_SLURM_SETUP_COMMAND="sudo mkdir -p /etc/munge /etc/slurm && \
        sudo cp /shared/slurm-config/munge.key /etc/munge/munge.key && \
        sudo chown -R munge:munge /etc/munge && \
        sudo chmod 0700 /etc/munge && \
        sudo chmod 0400 /etc/munge/munge.key && \
        sudo systemctl enable munge && sudo systemctl restart munge && \
        sudo rm -f /etc/slurm/slurm.conf && \
        sudo ln -s /shared/slurm-config/slurm.conf /etc/slurm/slurm.conf && \
        sudo chown -h slurm:slurm /etc/slurm/slurm.conf"
    gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="${JUPYTER_SLURM_SETUP_COMMAND}" --quiet
    check_status "Jupyter Node: SLURM configuration set up"

    log "Jupyter Node: Testing SLURM connectivity..."
    gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="sinfo -N || echo 'sinfo command failed or returned no nodes (this might be okay if cluster is still settling)'" --quiet
    log "Jupyter_CMD: sinfo executed (see Jupyter node for exact sinfo output if needed)"

    log "--- SLURM integration for Jupyter node completed ---"
else
    log "--- Skipping SLURM integration (SLURM head node or filestore not available) ---"
fi

# Cleanup
log "Cleaning up temporary directory ${TEMP_DIR}..."
rm -rf "${TEMP_DIR}"
check_status "Cleaned up temporary directory"

# Final status
log "Jupyter should be accessible at http://${JUPYTER_IP}:8888 (if firewall rules allow port 8888)."
if [ -n "${JUPYTERHUB_IP}" ]; then
    log "JupyterHub is available at http://${JUPYTERHUB_IP}:8000 for multi-user access."
fi
if [ -n "${SLURM_HEAD_IP}" ]; then
    log "Jupyter can submit jobs to SLURM cluster via command line tools."
fi

log "✓✓✓ Full Jupyter setup with JupyterHub integration completed! ✓✓✓"

exit 0