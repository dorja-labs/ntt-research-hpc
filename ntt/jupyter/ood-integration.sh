#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/jupyter_ood_integration-$(date +%Y%m%d-%H%M%S).log"
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

log "Starting Jupyter OOD integration..."

# Create a temporary directory for staging files
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: ${TEMP_DIR}"

# --- Instance IPs ---
log "Getting Jupyter node IP..."
JUPYTER_NODE_NAME="ntt-research-jupyter-0"
JUPYTER_IP=$(gcloud compute instances describe "${JUPYTER_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
check_status "Get Jupyter node IP for ${JUPYTER_NODE_NAME}"
log "Jupyter node IP: ${JUPYTER_IP}"

log "Getting OOD node IP..."
OOD_NODE_NAME="ntt-research-ood-0"
OOD_IP=$(gcloud compute instances describe "${OOD_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
check_status "Get OOD node IP for ${OOD_NODE_NAME}"
log "OOD node IP: ${OOD_IP}"

# --- OOD Node Configuration for Jupyter Integration ---
log "--- Initiating OOD node (${OOD_NODE_NAME}) configuration for Jupyter integration ---"

LOCAL_OOD_JUPYTER_CONFIG="ntt/ood/config/jupyter.yml"
TEMP_OOD_JUPYTER_CONFIG="${TEMP_DIR}/jupyter.ood.yml"

log "Checking for local OOD Jupyter definition file: ${LOCAL_OOD_JUPYTER_CONFIG}..."
if [ ! -f "${LOCAL_OOD_JUPYTER_CONFIG}" ]; then
    log "✗ Local OOD Jupyter definition file ${LOCAL_OOD_JUPYTER_CONFIG} not found!"
    exit 1
fi
check_status "Local OOD Jupyter definition file found"

# Prepare OOD's jupyter.yml by replacing placeholder with actual JUPYTER_IP
log "Preparing ${TEMP_OOD_JUPYTER_CONFIG} with JUPYTER_IP=${JUPYTER_IP}..."
cp "${LOCAL_OOD_JUPYTER_CONFIG}" "${TEMP_OOD_JUPYTER_CONFIG}"
check_status "Copied ${LOCAL_OOD_JUPYTER_CONFIG} to ${TEMP_OOD_JUPYTER_CONFIG}"
sed -i "s/\${JUPYTER_IP}/${JUPYTER_IP}/g" "${TEMP_OOD_JUPYTER_CONFIG}"
check_status "Replaced \${JUPYTER_IP} in ${TEMP_OOD_JUPYTER_CONFIG}"

# Copy the OOD Jupyter cluster config to the OOD node
log "Copying OOD Jupyter cluster config to ${OOD_NODE_NAME}..."
gcloud compute scp "${TEMP_OOD_JUPYTER_CONFIG}" "${OOD_NODE_NAME}:/tmp/jupyter.yml" --zone=us-central1-a --quiet
check_status "Copy OOD Jupyter cluster config to OOD node"

log "Installing OOD Jupyter cluster config on ${OOD_NODE_NAME}..."
gcloud compute ssh "${OOD_NODE_NAME}" --zone=us-central1-a --command="sudo mv /tmp/jupyter.yml /etc/ood/config/clusters.d/jupyter.yml && sudo chown root:root /etc/ood/config/clusters.d/jupyter.yml && sudo chmod 644 /etc/ood/config/clusters.d/jupyter.yml" --quiet
check_status "Install OOD Jupyter cluster config on OOD node"

# Create Jupyter app directory and configuration
log "Creating Jupyter app directory on OOD node..."
OOD_JUPYTER_SETUP="sudo mkdir -p /var/www/ood/apps/sys/jupyter && \
    sudo chown -R root:root /var/www/ood/apps/sys/jupyter && \
    echo 'title: Jupyter Lab
description: |
  This app will launch a Jupyter Lab server on the Jupyter node.

category: Interactive Apps' | sudo tee /var/www/ood/apps/sys/jupyter/manifest.yml"

gcloud compute ssh "${OOD_NODE_NAME}" --zone=us-central1-a --command="${OOD_JUPYTER_SETUP}" --quiet
check_status "Create Jupyter app directory and configuration on OOD node"

log "OOD Node: Updating OOD portal and restarting Apache..."
gcloud compute ssh "${OOD_NODE_NAME}" --zone=us-central1-a --command="sudo /opt/ood/ood-portal-generator/sbin/update_ood_portal && sudo systemctl restart apache2" --quiet
check_status "OOD Node: Portal updated and Apache restarted"

# Cleanup
log "Cleaning up temporary directory ${TEMP_DIR}..."
rm -rf "${TEMP_DIR}"
check_status "Cleaned up temporary directory"

log "--- OOD node Jupyter integration tasks finished. ---"
log "OOD portal should be accessible at http://${OOD_IP}"
log "Jupyter should be available in the Interactive Apps section"

log "✓✓✓ Full Jupyter OOD integration setup process completed successfully! ✓✓✓"
exit 0