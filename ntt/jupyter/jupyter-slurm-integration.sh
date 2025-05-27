#!/bin/bash

# Jupyter SLURM Integration Script
# This script configures SLURM client access on the standalone Jupyter node
# for command-line job submission

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

print_status "Starting Jupyter SLURM integration..."

# Get environment variables passed from setup script
FILESTORE_IP=${FILESTORE_IP:-""}
SLURM_HEAD_IP=${SLURM_HEAD_IP:-""}

if [ -z "$FILESTORE_IP" ]; then
    print_error "FILESTORE_IP not provided"
    exit 1
fi

if [ -z "$SLURM_HEAD_IP" ]; then
    print_error "SLURM_HEAD_IP not provided"
    exit 1
fi

print_status "Using filestore IP: $FILESTORE_IP"
print_status "Using SLURM head IP: $SLURM_HEAD_IP"

# Install SLURM client and MUNGE
print_status "Installing SLURM client and MUNGE..."
apt-get update -y
apt-get install -y munge libmunge-dev slurm-client=23.11.4*
check_status "SLURM client and MUNGE installation"

# Install NFS client if not already installed
print_status "Installing NFS client..."
apt-get install -y nfs-common
check_status "NFS client installation"

# Create mount point and mount shared storage
print_status "Setting up shared storage..."
mkdir -p /shared

# Mount the NFS share
if mount -t nfs ${FILESTORE_IP}:/ntt_storage /shared 2>/dev/null; then
    print_success "NFS share mounted successfully"
    echo "${FILESTORE_IP}:/ntt_storage /shared nfs defaults 0 0" >> /etc/fstab
else
    print_error "Failed to mount NFS share"
    exit 1
fi

# Wait for SLURM configuration files to be available
print_status "Waiting for SLURM configuration files..."
SHARED_SLURM_CONF="/shared/slurm-config/slurm.conf"
SHARED_MUNGE_KEY="/shared/slurm-config/munge.key"
MAX_WAIT_SECONDS=300 # Wait up to 5 minutes
WAIT_INTERVAL=10
ELAPSED_WAIT=0

while [ ! -f "$SHARED_SLURM_CONF" ] || [ ! -f "$SHARED_MUNGE_KEY" ]; do
    if [ $ELAPSED_WAIT -ge $MAX_WAIT_SECONDS ]; then
        print_error "SLURM config files not found after ${MAX_WAIT_SECONDS} seconds"
        exit 1
    fi
    sleep $WAIT_INTERVAL
    ((ELAPSED_WAIT += WAIT_INTERVAL))
    print_status "Waited ${ELAPSED_WAIT}s for SLURM configs..."
done

print_success "SLURM configuration files found"

# Set up MUNGE authentication
print_status "Setting up MUNGE authentication..."
mkdir -p /etc/munge
cp "$SHARED_MUNGE_KEY" /etc/munge/munge.key
chown -R munge:munge /etc/munge
chmod 0700 /etc/munge
chmod 0400 /etc/munge/munge.key
check_status "MUNGE key setup"

# Start MUNGE service
print_status "Starting MUNGE service..."
systemctl enable munge
systemctl restart munge
systemctl is-active --quiet munge
check_status "MUNGE service start"

# Set up SLURM configuration
print_status "Setting up SLURM configuration..."
mkdir -p /etc/slurm
rm -f /etc/slurm/slurm.conf
ln -s "$SHARED_SLURM_CONF" /etc/slurm/slurm.conf
chown -h slurm:slurm /etc/slurm/slurm.conf
check_status "SLURM configuration setup"

# Test SLURM connectivity
print_status "Testing SLURM connectivity..."
if sinfo -N >/dev/null 2>&1; then
    print_success "SLURM cluster is accessible"
    sinfo
else
    print_error "SLURM cluster is not accessible yet (this might be normal if cluster is still starting)"
fi

# Create Jupyter workspace on shared storage
print_status "Creating Jupyter workspace on shared storage..."
mkdir -p /shared/jupyter-workspace
chmod 755 /shared/jupyter-workspace
check_status "Jupyter workspace creation"

# Create SLURM job submission examples for Jupyter users
print_status "Creating SLURM job examples..."
cat > /shared/jupyter-workspace/slurm_examples.py << 'EOF'
#!/usr/bin/env python3
"""
SLURM Job Submission Examples for Jupyter
This file contains examples of how to submit SLURM jobs from Jupyter notebooks.
"""

import subprocess
import os

def submit_slurm_job(script_content, job_name="jupyter_job", partition="debug", time="1:00:00", cpus=1, memory="1G"):
    """
    Submit a SLURM job from Jupyter

    Args:
        script_content (str): The script content to run
        job_name (str): Name for the job
        partition (str): SLURM partition to use
        time (str): Time limit for the job
        cpus (int): Number of CPUs to request
        memory (str): Memory to request

    Returns:
        str: Job ID if successful, None if failed
    """

    # Create a temporary script file
    script_path = f"/tmp/{job_name}.sh"
    with open(script_path, 'w') as f:
        f.write(script_content)

    # Make it executable
    os.chmod(script_path, 0o755)

    # Submit the job
    cmd = [
        'sbatch',
        f'--job-name={job_name}',
        f'--partition={partition}',
        f'--time={time}',
        f'--cpus-per-task={cpus}',
        f'--mem={memory}',
        f'--output=/shared/jupyter-workspace/{job_name}-%j.out',
        f'--error=/shared/jupyter-workspace/{job_name}-%j.err',
        script_path
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        job_id = result.stdout.strip().split()[-1]
        print(f"Job submitted successfully! Job ID: {job_id}")
        return job_id
    except subprocess.CalledProcessError as e:
        print(f"Failed to submit job: {e.stderr}")
        return None

def check_job_status(job_id):
    """Check the status of a SLURM job"""
    try:
        result = subprocess.run(['squeue', '-j', str(job_id)], capture_output=True, text=True, check=True)
        print(result.stdout)
    except subprocess.CalledProcessError:
        print(f"Job {job_id} not found in queue (may have completed)")

def get_job_output(job_name, job_id):
    """Get the output of a completed job"""
    output_file = f"/shared/jupyter-workspace/{job_name}-{job_id}.out"
    error_file = f"/shared/jupyter-workspace/{job_name}-{job_id}.err"

    print("=== Job Output ===")
    try:
        with open(output_file, 'r') as f:
            print(f.read())
    except FileNotFoundError:
        print("Output file not found")

    print("=== Job Errors ===")
    try:
        with open(error_file, 'r') as f:
            error_content = f.read()
            if error_content.strip():
                print(error_content)
            else:
                print("No errors")
    except FileNotFoundError:
        print("Error file not found")

# Example usage:
if __name__ == "__main__":
    # Example 1: Simple Python script
    python_script = """#!/bin/bash
#SBATCH --job-name=python_example

python3 -c "
import time
print('Hello from SLURM!')
print('Running some computation...')
time.sleep(10)
print('Computation complete!')
"
"""

    job_id = submit_slurm_job(python_script, "python_example")
    if job_id:
        print(f"Monitor job with: squeue -j {job_id}")
        print(f"Check output with: get_job_output('python_example', '{job_id}')")
EOF

chmod 644 /shared/jupyter-workspace/slurm_examples.py
check_status "SLURM examples creation"

print_success "Jupyter SLURM integration completed successfully!"
print_status "Jupyter can now submit jobs to SLURM cluster via command line"
print_status "SLURM examples available at: /shared/jupyter-workspace/slurm_examples.py"
print_status "SLURM cluster status:"
sinfo || echo "SLURM cluster not ready yet"