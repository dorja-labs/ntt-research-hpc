#!/bin/bash

# Demonstration script showing the NFS-based workflow
# This replaces the old SCP-based approach

set -e

echo "=== NFS-Based Setup Workflow Demonstration ==="

# Step 1: Ensure NFS shared storage is mounted
echo "Step 1: Ensuring NFS shared storage is mounted..."
if ! sudo ./ntt/ensure-nfs-mount.sh; then
    echo "✗ Failed to mount NFS shared storage"
    exit 1
fi

# Step 2: Copy a test script to NFS shared storage
echo "Step 2: Copying test script to NFS shared storage..."
SHARED_SCRIPTS_DIR="/shared/scripts"
sudo mkdir -p "${SHARED_SCRIPTS_DIR}"

# Create a test script
cat > /tmp/demo-script.sh << 'EOF'
#!/bin/bash
echo "=== Demo Script Execution ==="
echo "Script executed from: $(hostname)"
echo "Timestamp: $(date)"
echo "Current user: $(whoami)"
echo "NFS shared storage is working!"
EOF

sudo cp /tmp/demo-script.sh "${SHARED_SCRIPTS_DIR}/"
sudo chmod +x "${SHARED_SCRIPTS_DIR}/demo-script.sh"
echo "✓ Test script copied to ${SHARED_SCRIPTS_DIR}/demo-script.sh"

# Step 3: Execute the script from remote nodes
echo "Step 3: Executing script from remote nodes..."

echo "  → Executing on SLURM head node..."
gcloud compute ssh ntt-research-hpc-slurm-0 --zone=us-central1-a --command="sudo /shared/scripts/demo-script.sh" --quiet

echo "  → Executing on SLURM compute node..."
gcloud compute ssh ntt-research-hpc-slurm-1 --zone=us-central1-a --command="sudo /shared/scripts/demo-script.sh" --quiet

echo "  → Executing on OOD node..."
gcloud compute ssh ntt-research-ood-0 --zone=us-central1-a --command="sudo /shared/scripts/demo-script.sh" --quiet

echo "=== NFS-Based Workflow Demo Complete ==="
echo "✓ All nodes successfully executed the script from NFS shared storage"
echo "✓ No SCP transfers needed!"

# Cleanup
rm -f /tmp/demo-script.sh
echo "✓ Temporary files cleaned up"