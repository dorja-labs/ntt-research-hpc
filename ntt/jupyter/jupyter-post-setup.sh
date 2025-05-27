#!/bin/bash

# Exit on error
set -e

# Setup logging
LOG_FILE="/tmp/jupyter-post-setup-$(date +%Y%m%d-%H%M%S).log"
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

log "Starting Jupyter post-setup on the instance..."

# --- User Configuration ---
JUPYTER_USER="jupyteruser"
JUPYTER_PASSWORD="DefaultJupyterPass123!" # !!! CHANGE THIS DEFAULT PASSWORD !!!
log "WARNING: Using default Jupyter user '${JUPYTER_USER}' with password '${JUPYTER_PASSWORD}'. This MUST be changed for a secure environment."

# Create Jupyter user if it doesn't exist
if ! id -u "${JUPYTER_USER}" >/dev/null 2>&1; then
    log "Creating user ${JUPYTER_USER}..."
    sudo useradd -m -s /bin/bash "${JUPYTER_USER}"
    check_status "Create user ${JUPYTER_USER}"
else
    log "User ${JUPYTER_USER} already exists."
fi

log "Setting password for ${JUPYTER_USER}..."
echo "${JUPYTER_USER}:${JUPYTER_PASSWORD}" | sudo chpasswd
check_status "Set password for ${JUPYTER_USER}"
# --- End User Configuration ---

# --- Package Installation ---
log "Installing required packages..."
sudo apt-get update -y

# Install Python3, pip, and SLURM compute node packages
log "Installing Python3, pip, and SLURM compute node packages..."
sudo apt-get install -y python3 python3-pip python3-venv python3-dev build-essential \
    nfs-common munge libmunge-dev slurm-wlm=23.11.4* slurm-client=23.11.4*
check_status "Install required packages"

# Create a Python virtual environment for Jupyter
log "Creating Python virtual environment for Jupyter in /opt/jupyter_env..."
sudo python3 -m venv /opt/jupyter_env
check_status "Create Python virtual environment"

# Upgrade pip and install wheel
log "Upgrading pip and installing wheel..."
sudo /opt/jupyter_env/bin/pip install --upgrade pip wheel
check_status "Upgrade pip and install wheel"

# Install JupyterLab and SLURM-related packages in the virtual environment
log "Installing JupyterLab and SLURM packages..."
sudo /opt/jupyter_env/bin/pip install jupyterlab jupyter-server jupyterlab-slurm
check_status "Install JupyterLab and SLURM packages"

# --- SLURM Integration ---
log "Setting up SLURM integration..."

# Check if SLURM integration script is available
if [ -f "/tmp/jupyter-slurm-integration.sh" ]; then
    log "Running SLURM integration script..."
    chmod +x /tmp/jupyter-slurm-integration.sh
    bash /tmp/jupyter-slurm-integration.sh
    check_status "SLURM integration script execution"
else
    log "SLURM integration script not found, setting up basic SLURM client..."

    # Create SLURM directories
    log "Creating SLURM directories..."
    sudo mkdir -p /etc/slurm
    sudo mkdir -p /var/log/slurm-llnl
    sudo mkdir -p /var/lib/slurm-llnl/slurmd
    sudo mkdir -p /var/run/slurm-llnl
    sudo chown -R slurm:slurm /var/lib/slurm-llnl
    sudo chown -R slurm:slurm /var/log/slurm-llnl
    sudo chown -R slurm:slurm /var/run/slurm-llnl
    sudo chmod -R 755 /var/log/slurm-llnl
    check_status "Create SLURM directories"

    # Create basic SLURM configuration
    log "Creating basic SLURM configuration..."
    sudo bash -c "cat > /etc/slurm/slurm.conf" << 'EOF'
# Basic SLURM configuration for Jupyter client
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
MailProg=/bin/true
PluginDir=/usr/lib/x86_64-linux-gnu/slurm-wlm

# Node definitions
NodeName=ntt-research-hpc-slurm-0 NodeAddr=ntt-research-hpc-slurm-0 CPUs=4 RealMemory=32094 State=UNKNOWN
NodeName=ntt-research-hpc-slurm-1 NodeAddr=ntt-research-hpc-slurm-1 CPUs=4 RealMemory=32094 State=UNKNOWN

# Partition definitions
PartitionName=debug Nodes=ntt-research-hpc-slurm-0,ntt-research-hpc-slurm-1 Default=YES MaxTime=INFINITE State=UP
EOF
    sudo chown slurm:slurm /etc/slurm/slurm.conf
    sudo chmod 644 /etc/slurm/slurm.conf
    check_status "Create basic SLURM configuration"

    # Generate a basic munge key
    log "Generating basic munge key..."
    sudo mkdir -p /etc/munge
    sudo dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
    sudo chown munge:munge /etc/munge/munge.key
    sudo chmod 400 /etc/munge/munge.key
    check_status "Generate basic munge key"

    # Start munge service
    log "Starting munge service..."
    sudo systemctl enable munge
    sudo systemctl restart munge
    check_status "Start munge service"
fi

# Start SLURM compute node service
log "Starting SLURM compute node service..."
sudo systemctl enable slurmd
sudo systemctl restart slurmd
check_status "Start SLURM compute node service"

# --- Jupyter Configuration for jupyteruser ---
JUPYTER_USER_HOME="/home/${JUPYTER_USER}"
JUPYTER_CONFIG_DIR="${JUPYTER_USER_HOME}/.jupyter"
JUPYTER_LOCAL_DIR="${JUPYTER_USER_HOME}/.local"
JUPYTER_CONFIG_PATH="${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py"

log "Creating Jupyter config and local directories for ${JUPYTER_USER}..."
sudo mkdir -p "${JUPYTER_CONFIG_DIR}"
sudo mkdir -p "${JUPYTER_LOCAL_DIR}"
sudo chown -R "${JUPYTER_USER}:${JUPYTER_USER}" "${JUPYTER_LOCAL_DIR}"
sudo chown -R "${JUPYTER_USER}:${JUPYTER_USER}" "${JUPYTER_CONFIG_DIR}"
check_status "Create and chown Jupyter directories"

# Generate a default Jupyter configuration as jupyteruser
log "Generating default Jupyter configuration as ${JUPYTER_USER}..."
sudo -u "${JUPYTER_USER}" -H /opt/jupyter_env/bin/jupyter lab --generate-config
if [ ! -f "${JUPYTER_CONFIG_PATH}" ]; then
    log "✗ Jupyter config ${JUPYTER_CONFIG_PATH} not found after generate-config. This is an error."
    exit 1
else
   log "✓ Found Jupyter config at ${JUPYTER_CONFIG_PATH}"
fi

# Generate hashed password for JupyterLab
log "Generating hashed password for JupyterLab..."
HASHED_PASSWORD=$(sudo -u "${JUPYTER_USER}" /opt/jupyter_env/bin/python -c "from jupyter_server.auth import passwd; print(passwd('${JUPYTER_PASSWORD}', 'sha256'))")
check_status "Generate hashed password"
log "Hashed password generated." # Do not log the hash itself for security

# Basic configuration (allow all IPs, run on port 8888)
if [ -f "${JUPYTER_CONFIG_PATH}" ]; then
    log "Updating Jupyter configuration in ${JUPYTER_CONFIG_PATH} for user ${JUPYTER_USER}..."
    # Ensure config file is writable by the user temporarily if needed, or use sudo tee
    sudo chmod 666 "${JUPYTER_CONFIG_PATH}" # Temporarily make writable for sed

    # Basic server configuration
    sudo sed -i "/#c.ServerApp.ip/c\\c.ServerApp.ip = '0.0.0.0'" "${JUPYTER_CONFIG_PATH}"
    sudo sed -i "/#c.ServerApp.port/c\\c.ServerApp.port = 8888" "${JUPYTER_CONFIG_PATH}"
    sudo sed -i "/#c.ServerApp.token/c\\c.ServerApp.token = ''" "${JUPYTER_CONFIG_PATH}" # Disable token, we use password
    sudo sed -i "/#c.ServerApp.password/c\\c.ServerApp.password = u'${HASHED_PASSWORD}'" "${JUPYTER_CONFIG_PATH}"
    sudo sed -i "/#c.ServerApp.open_browser/c\\c.ServerApp.open_browser = False" "${JUPYTER_CONFIG_PATH}"
    sudo sed -i "/#c.ServerApp.allow_root/c\\c.ServerApp.allow_root = False" "${JUPYTER_CONFIG_PATH}" # Run as jupyteruser

    # Additional remote access configuration
    echo "c.ServerApp.allow_origin = '*'" | sudo tee -a "${JUPYTER_CONFIG_PATH}"
    echo "c.ServerApp.allow_remote_access = True" | sudo tee -a "${JUPYTER_CONFIG_PATH}"
    echo "c.ServerApp.base_url = '/jupyter'" | sudo tee -a "${JUPYTER_CONFIG_PATH}"
    echo "c.ServerApp.trust_xheaders = True" | sudo tee -a "${JUPYTER_CONFIG_PATH}"

    sudo chmod 644 "${JUPYTER_CONFIG_PATH}" # Restore permissions
    sudo chown "${JUPYTER_USER}:${JUPYTER_USER}" "${JUPYTER_CONFIG_PATH}"
    check_status "Update Jupyter configuration for ${JUPYTER_USER}"
else
    log "✗ Jupyter config file not found at ${JUPYTER_CONFIG_PATH}, skipping configuration update."
    exit 1
fi

# --- Jupyter Configuration ---
log "Configuring Jupyter..."
mkdir -p /etc/jupyter
cat > /etc/jupyter/jupyter_notebook_config.py << 'EOF'
c = get_config()
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False
c.NotebookApp.allow_root = True
c.NotebookApp.token = ''
c.NotebookApp.password = ''
c.NotebookApp.allow_origin = '*'
c.NotebookApp.base_url = '/jupyter/'
c.NotebookApp.trust_xheaders = True
c.NotebookApp.tornado_settings = {
    'headers': {
        'Content-Security-Policy': "frame-ancestors 'self' http://ntt-research-jupyterhub-0:*"
    }
}
EOF
check_status "Configure Jupyter"
# --- End Jupyter Configuration ---

# --- Systemd Service Setup ---
SYSTEMD_SERVICE_FILE="/etc/systemd/system/jupyter.service"
log "Creating systemd service file at ${SYSTEMD_SERVICE_FILE}..."

sudo bash -c "cat > ${SYSTEMD_SERVICE_FILE}" << EOL
[Unit]
Description=JupyterLab for ${JUPYTER_USER}
After=network.target

[Service]
User=${JUPYTER_USER}
Group=${JUPYTER_USER}
Type=simple
WorkingDirectory=${JUPYTER_USER_HOME}
ExecStart=/opt/jupyter_env/bin/jupyter lab --config=${JUPYTER_CONFIG_PATH}
Restart=always
RestartSec=10
Environment="PATH=/opt/jupyter_env/bin:\${PATH}"
Environment="PYTHONPATH=/opt/jupyter_env/lib/python3.12/site-packages"

[Install]
WantedBy=multi-user.target
EOL
check_status "Create systemd service file"

log "Reloading systemd daemon..."
sudo systemctl daemon-reload
check_status "Systemd daemon-reload"

log "Enabling Jupyter service to start on boot..."
sudo systemctl enable jupyter.service
check_status "Enable Jupyter service"

log "Starting Jupyter service..."
sudo systemctl start jupyter.service
check_status "Start Jupyter service"

log "Checking Jupyter service status..."
# Give it a couple of seconds to start
sleep 5
sudo systemctl status jupyter.service --no-pager || log "Warning: Jupyter service status check indicated an issue."
# --- End Systemd Service Setup ---

log "--- Firewall Reminder ---"
log "IMPORTANT: Ensure that your GCP firewall rules allow TCP ingress traffic on port 8888 to this instance."
log "You might need to add a new firewall rule or ensure the instance has a network tag (e.g., 'http-server' or 'jupyter-server') associated with such a rule."
log "--- End Firewall Reminder ---"

log "✓ Jupyter post-setup on instance completed successfully."
log "JupyterLab should be accessible as user '${JUPYTER_USER}' with the configured password at http://<YOUR_INSTANCE_IP>:8888"
log "Remember to change the default password for '${JUPYTER_USER}' and in JupyterLab configuration if you haven't already!"
exit 0