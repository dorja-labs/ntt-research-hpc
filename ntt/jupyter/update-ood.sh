#!/bin/bash

set -e

echo "Installing Jupyter batch_connect app to OOD..."

# Get OOD node name and IP
OOD_NODE_NAME="ntt-research-ood-0"
OOD_IP=$(gcloud compute instances describe "${OOD_NODE_NAME}" --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
echo "OOD node IP: ${OOD_IP}"

# Create temporary directory for staging
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: ${TEMP_DIR}"

# Copy app files to staging area
mkdir -p "${TEMP_DIR}/jupyter/template"
cp ntt/jupyter/manifest.yml "${TEMP_DIR}/jupyter/"
cp ntt/jupyter/form.yml "${TEMP_DIR}/jupyter/"
cp ntt/jupyter/submit.yml.erb "${TEMP_DIR}/jupyter/"
cp ntt/jupyter/template/script.sh.erb "${TEMP_DIR}/jupyter/template/"

# Copy files to OOD node
echo "Copying app files to OOD node..."
gcloud compute scp --recurse "${TEMP_DIR}/jupyter" "${OOD_NODE_NAME}:/tmp/" --zone=us-central1-a --quiet

# Install app on OOD node
echo "Installing Jupyter app..."
INSTALL_CMD='sudo rm -rf /var/www/ood/apps/sys/jupyter && \
             sudo mkdir -p /var/www/ood/apps/sys/jupyter && \
             sudo cp -r /tmp/jupyter/* /var/www/ood/apps/sys/jupyter/ && \
             sudo chown -R ood:ood /var/www/ood/apps/sys/jupyter && \
             sudo chmod -R 755 /var/www/ood/apps/sys/jupyter && \
             sudo systemctl restart apache2'

gcloud compute ssh "${OOD_NODE_NAME}" --zone=us-central1-a --command="${INSTALL_CMD}" --quiet

# Cleanup
rm -rf "${TEMP_DIR}"

echo "✅ Jupyter batch_connect app installed successfully!"
echo "OOD portal: http://${OOD_IP}"
echo "Check Interactive Apps section for 'Jupyter Lab'"

exit 0