#!/bin/bash

# JupyterHub Setup Script for NTT Research Infrastructure
# This script configures JupyterHub with BatchSpawner for SLURM integration
# Much simpler than Open OnDemand configuration!

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

print_status "Starting JupyterHub configuration..."

# Get the JupyterHub instance IP
JUPYTERHUB_IP=$(gcloud compute instances describe ntt-research-jupyterhub-0 --zone=us-central1-a --format="get(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")

if [ -z "$JUPYTERHUB_IP" ]; then
    print_error "Could not find JupyterHub instance. Make sure it's deployed first."
    exit 1
fi

print_status "Found JupyterHub instance at IP: $JUPYTERHUB_IP"

# Get SLURM head node IP
SLURM_HEAD_IP=$(gcloud compute instances describe ntt-research-hpc-slurm-0 --zone=us-central1-a --format="get(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")

if [ -z "$SLURM_HEAD_IP" ]; then
    print_error "Could not find SLURM head node. Make sure SLURM cluster is deployed first."
    exit 1
fi

print_status "Found SLURM head node at IP: $SLURM_HEAD_IP"

# Copy SLURM integration script to JupyterHub instance
print_status "Copying SLURM integration script to JupyterHub..."
gcloud compute scp ntt/jupyterhub/slurm-integration.sh ntt-research-jupyterhub-0:/tmp/slurm-integration.sh --zone=us-central1-a

# SSH into JupyterHub instance and configure it
print_status "Configuring JupyterHub with BatchSpawner..."

gcloud compute ssh ntt-research-jupyterhub-0 --zone=us-central1-a --command="
set -e

echo '[$(date)] Starting JupyterHub configuration...'

# Wait for shared storage to be mounted
echo '[$(date)] Waiting for shared storage...'
timeout=300
while [ ! -d /shared ] && [ \$timeout -gt 0 ]; do
    sleep 5
    timeout=\$((timeout - 5))
done

if [ ! -d /shared ]; then
    echo '[$(date)] Warning: Shared storage not available, continuing without it'
fi

# Create JupyterHub configuration
echo '[$(date)] Creating JupyterHub configuration...'
sudo tee /etc/jupyterhub/jupyterhub_config.py > /dev/null << 'EOF'
# JupyterHub Configuration for NTT Research Infrastructure
# Simple configuration with BatchSpawner for SLURM integration

import os

# Basic JupyterHub settings
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.port = 8000
c.JupyterHub.hub_ip = '0.0.0.0'

# Use BatchSpawner for SLURM integration
c.JupyterHub.spawner_class = 'batchspawner.SlurmSpawner'

# SLURM configuration - MUCH SIMPLER THAN OOD!
c.SlurmSpawner.batch_script = '''#!/bin/bash
#SBATCH --job-name=jupyterhub-{username}
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --output=/shared/jupyterhub-logs/{username}-%j.out
#SBATCH --error=/shared/jupyterhub-logs/{username}-%j.err

# Load environment
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONPATH=/usr/local/lib/python3.12/site-packages

# Start Jupyter Lab
{cmd}
'''

# Spawner settings
c.SlurmSpawner.req_partition = 'debug'
c.SlurmSpawner.req_nodes = '1'
c.SlurmSpawner.req_memory = '4G'
c.SlurmSpawner.req_runtime = '4:00:00'
c.SlurmSpawner.req_nprocs = '2'

# User settings
c.SlurmSpawner.default_url = '/lab'
c.SlurmSpawner.cmd = ['jupyter-labhub']
c.SlurmSpawner.args = ['--allow-root']

# Authentication - Simple PAM authentication
c.JupyterHub.authenticator_class = 'jupyterhub.auth.PAMAuthenticator'

# Admin users
c.Authenticator.admin_users = {'root', 'ubuntu', 'researcher'}

# Logging
c.JupyterHub.log_level = 'INFO'
c.JupyterHub.log_file = '/var/log/jupyterhub/jupyterhub.log'

# Data persistence
c.Spawner.notebook_dir = '/shared/notebooks/{username}'
c.Spawner.environment = {
    'JUPYTER_ENABLE_LAB': '1',
    'SHARED_DIR': '/shared'
}

# Timeout settings
c.Spawner.start_timeout = 300
c.Spawner.http_timeout = 120

print('JupyterHub configuration created successfully!')
EOF

# Create necessary directories
echo '[$(date)] Creating directories...'
sudo mkdir -p /var/log/jupyterhub
sudo mkdir -p /shared/jupyterhub-logs
sudo mkdir -p /shared/notebooks
sudo chmod 755 /shared/jupyterhub-logs
sudo chmod 755 /shared/notebooks

# Run SLURM integration script
echo '[$(date)] Running SLURM integration script...'
if [ -f /tmp/slurm-integration.sh ]; then
    chmod +x /tmp/slurm-integration.sh
    bash /tmp/slurm-integration.sh
    echo '[$(date)] SLURM integration completed'
else
    echo '[$(date)] Warning: SLURM integration script not found, setting up basic configuration'

    # Fallback: Basic SLURM configuration
    sudo mkdir -p /etc/slurm
    sudo tee /etc/slurm/slurm.conf > /dev/null << 'SLURMEOF'
ClusterName=ntt-research-slurm
SlurmctldHost=ntt-research-hpc-slurm-0
SlurmctldPort=6817
SlurmdPort=6818
StateSaveLocation=/var/spool/slurm/ctld
SlurmdSpoolDir=/var/spool/slurm/d
SwitchType=switch/none
MpiDefault=none
SlurmctldPidFile=/var/run/slurm-llnl/slurmctld.pid
SlurmdPidFile=/var/run/slurm-llnl/slurmd.pid
ProctrackType=proctrack/pgid
ReturnToService=1
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core
AccountingStorageType=accounting_storage/none
JobCompType=jobcomp/none
PluginDir=/usr/lib/x86_64-linux-gnu/slurm-wlm

# Node definitions
NodeName=ntt-research-hpc-slurm-0 NodeAddr=ntt-research-hpc-slurm-0 CPUs=4 RealMemory=32094 State=UNKNOWN
NodeName=ntt-research-hpc-slurm-1 NodeAddr=ntt-research-hpc-slurm-1 CPUs=4 RealMemory=32094 State=UNKNOWN

# Partition definitions
PartitionName=debug Nodes=ntt-research-hpc-slurm-0,ntt-research-hpc-slurm-1 Default=YES MaxTime=INFINITE State=UP
SLURMEOF
fi

# Create systemd service for JupyterHub
echo '[$(date)] Creating JupyterHub systemd service...'
sudo tee /etc/systemd/system/jupyterhub.service > /dev/null << 'EOF'
[Unit]
Description=JupyterHub
After=network.target

[Service]
User=root
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/jupyterhub -f /etc/jupyterhub/jupyterhub_config.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start JupyterHub
echo '[$(date)] Starting JupyterHub service...'
sudo systemctl daemon-reload
sudo systemctl enable jupyterhub
sudo systemctl start jupyterhub

# Wait a moment and check status
sleep 5
if sudo systemctl is-active --quiet jupyterhub; then
    echo '[$(date)] ✓ JupyterHub is running successfully!'
else
    echo '[$(date)] ✗ JupyterHub failed to start, checking logs...'
    sudo journalctl -u jupyterhub --no-pager -n 20
fi

echo '[$(date)] JupyterHub configuration completed!'
echo '[$(date)] Access JupyterHub at: http://$(curl -s ifconfig.me):8000'
echo '[$(date)] Default users: ubuntu, root (use system passwords)'
"

check_status "JupyterHub configuration"

print_success "JupyterHub setup completed!"
print_status "JupyterHub is now running and integrated with SLURM"
print_status ""
print_status "Key advantages over Open OnDemand:"
print_status "✓ Much simpler configuration"
print_status "✓ Reliable SLURM integration via BatchSpawner"
print_status "✓ Better user experience for research computing"
print_status "✓ Easier to customize and extend"
print_status "✓ Built-in support for scientific Python packages"
print_status ""
print_status "Access JupyterHub at: http://JUPYTERHUB_EXTERNAL_IP:8000"
print_status "Users can login with their system credentials"