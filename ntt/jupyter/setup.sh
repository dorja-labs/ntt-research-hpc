#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/jupyter_setup-$(date +%Y%m%d-%H%M%S).log"
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

log "Starting Jupyter setup from control machine..."

# Create a temporary directory for staging files
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: ${TEMP_DIR}"

# --- Instance IP ---
# Assuming your Jupyter instance is named 'ntt-research-jupyter-0'
# and is in 'us-central1-a'. Adjust if necessary.
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

# Copy the script to the Jupyter node
log "Copying post-setup script to Jupyter node..."
gcloud compute scp "${TEMP_DIR}/jupyter-post-setup.sh" "${JUPYTER_NODE_NAME}:/tmp/jupyter-post-setup.sh" --zone="${JUPYTER_ZONE}" --quiet
check_status "Copy post-setup script to Jupyter node"

# Execute the script on the Jupyter node
log "Executing script on ${JUPYTER_NODE_NAME}..."
gcloud compute ssh "${JUPYTER_NODE_NAME}" --zone="${JUPYTER_ZONE}" --command="sudo bash /tmp/jupyter-post-setup.sh" --quiet
check_status "Execute script on Jupyter node"
log "--- Jupyter node setup script finished. Check its log on ${JUPYTER_NODE_NAME} in /tmp/ for details. ---"

# Cleanup
log "Cleaning up temporary directory ${TEMP_DIR}..."
rm -rf "${TEMP_DIR}"
check_status "Cleaned up temporary directory"

log "Jupyter should be accessible at http://${JUPYTER_IP}:8888 (if firewall rules allow port 8888)."
log "✓✓✓ Full Jupyter setup process completed! ✓✓✓"

exit 0