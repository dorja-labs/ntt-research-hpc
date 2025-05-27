# SLURM Registration with JupyterHub Integration

## 🔄 Overview

This document describes the updated SLURM registration system that integrates with **JupyterHub** instead of Open OnDemand (OOD). The new system provides simpler configuration, more reliable integration, and better support for research computing workflows.

## 📁 Updated File Structure

### SLURM Configuration (`./ntt/hpc-slurm/`)
- `setup.sh` - Main SLURM setup script (updated for JupyterHub)
- `slurm.conf` - SLURM cluster configuration (updated node definitions)
- `hpc-slurm-post-setup.sh` - SLURM node post-setup script

### JupyterHub Integration (`./ntt/jupyterhub/`)
- `setup.sh` - JupyterHub setup script with SLURM integration
- `slurm-integration.sh` - **NEW** - Dedicated SLURM integration script for JupyterHub

### Jupyter Integration (`./ntt/jupyter/`)
- `setup.sh` - Updated Jupyter setup script
- `jupyter-slurm-integration.sh` - **NEW** - SLURM integration for standalone Jupyter
- `jupyter-post-setup.sh` - Updated to use new integration script

## 🔧 Key Changes

### 1. SLURM Setup Script (`ntt/hpc-slurm/setup.sh`)

**Before (OOD Integration):**
```bash
# OOD Node Configuration for SLURM Integration
OOD_NODE_NAME="ntt-research-ood-0"
# Complex OOD-specific configuration...
```

**After (JupyterHub Integration):**
```bash
# JupyterHub Node Configuration for SLURM Integration
JUPYTERHUB_NODE_NAME="ntt-research-jupyterhub-0"
if [ -n "${JUPYTERHUB_IP}" ]; then
    # Simple SLURM client setup for JupyterHub
    # No complex OOD portal configuration needed
fi
```

**Key Improvements:**
- ✅ Simplified configuration (no OOD portal setup)
- ✅ Conditional JupyterHub integration (graceful fallback)
- ✅ Standard SLURM client setup instead of OOD-specific configs
- ✅ Better error handling and logging

### 2. SLURM Configuration (`ntt/hpc-slurm/slurm.conf`)

**Before:**
```ini
# Node definitions included Jupyter node as compute node
NodeName=ntt-research-jupyter-0 NodeAddr=ntt-research-jupyter-0 CPUs=2 RealMemory=15990 State=UNKNOWN
PartitionName=debug Nodes=ntt-research-hpc-slurm-0,ntt-research-hpc-slurm-1,ntt-research-jupyter-0
```

**After:**
```ini
# Clean node definitions - only actual compute nodes
NodeName=ntt-research-hpc-slurm-0 NodeAddr=ntt-research-hpc-slurm-0 CPUs=4 RealMemory=32094 State=UNKNOWN
NodeName=ntt-research-hpc-slurm-1 NodeAddr=ntt-research-hpc-slurm-1 CPUs=4 RealMemory=32094 State=UNKNOWN
PartitionName=debug Nodes=ntt-research-hpc-slurm-0,ntt-research-hpc-slurm-1
```

**Benefits:**
- ✅ Cleaner cluster definition
- ✅ JupyterHub and Jupyter nodes are SLURM clients, not compute nodes
- ✅ Better resource management

### 3. JupyterHub SLURM Integration (`ntt/jupyterhub/slurm-integration.sh`)

**New dedicated script that:**
- 🔧 Installs SLURM client and MUNGE on JupyterHub node
- 🔧 Mounts shared storage for configuration sharing
- 🔧 Waits for SLURM configuration files from head node
- 🔧 Sets up MUNGE authentication
- 🔧 Links shared SLURM configuration
- 🔧 Tests SLURM connectivity
- 🔧 Creates JupyterHub-specific directories

**Usage in JupyterHub setup:**
```bash
# Copy integration script to JupyterHub node
gcloud compute scp ntt/jupyterhub/slurm-integration.sh ntt-research-jupyterhub-0:/tmp/slurm-integration.sh

# Run integration during JupyterHub configuration
bash /tmp/slurm-integration.sh
```

### 4. Jupyter SLURM Integration (`ntt/jupyter/jupyter-slurm-integration.sh`)

**New script for standalone Jupyter that:**
- 🔧 Sets up SLURM client for command-line job submission
- 🔧 Creates Jupyter workspace on shared storage
- 🔧 Provides Python examples for SLURM job submission
- 🔧 Configures MUNGE authentication
- 🔧 Tests SLURM connectivity

**Features:**
```python
# Example SLURM job submission from Jupyter
import subprocess

def submit_slurm_job(script_content, job_name="jupyter_job"):
    # Submit job to SLURM cluster
    result = subprocess.run(['sbatch', '--job-name', job_name, script_path])
    return job_id
```

## 🚀 Deployment Workflow

### 1. Deploy Infrastructure Components
```bash
# Deploy in dependency order
./ctrl.sh create network
./ctrl.sh create storage
./ctrl.sh create hpc-slurm    # Sets up SLURM cluster + JupyterHub integration
./ctrl.sh create jupyterhub   # Sets up JupyterHub with BatchSpawner
./ctrl.sh create jupyter      # Sets up standalone Jupyter with SLURM client
```

### 2. SLURM Integration Flow

**Step 1: SLURM Cluster Setup**
- SLURM head node creates shared configuration
- SLURM compute nodes join cluster
- Configuration files stored on shared NFS

**Step 2: JupyterHub Integration**
- JupyterHub node installs SLURM client
- Mounts shared storage
- Copies SLURM configuration and MUNGE key
- Configures BatchSpawner for job submission

**Step 3: Jupyter Integration**
- Jupyter node installs SLURM client
- Sets up command-line job submission
- Creates workspace with examples
- Provides Python utilities for job management

## 🔍 Integration Details

### JupyterHub BatchSpawner Configuration

JupyterHub uses BatchSpawner to submit user sessions as SLURM jobs:

```python
# JupyterHub configuration
c.JupyterHub.spawner_class = 'batchspawner.SlurmSpawner'

c.SlurmSpawner.batch_script = '''#!/bin/bash
#SBATCH --job-name=jupyterhub-{username}
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00

{cmd}
'''
```

### Shared Storage Structure

```
/shared/
├── slurm-config/
│   ├── slurm.conf          # Shared SLURM configuration
│   └── munge.key           # Shared MUNGE authentication key
├── jupyterhub-logs/        # JupyterHub job logs
├── notebooks/              # User notebook directories
└── jupyter-workspace/      # Standalone Jupyter workspace
    └── slurm_examples.py   # SLURM job submission examples
```

### Authentication Flow

1. **MUNGE Key Generation**: SLURM head node generates shared key
2. **Key Distribution**: Stored on shared NFS storage
3. **Client Setup**: JupyterHub and Jupyter nodes copy key
4. **Service Start**: MUNGE services started on all nodes
5. **SLURM Access**: Clients can now submit jobs to cluster

## 🛠️ Troubleshooting

### Check SLURM Integration Status

**On SLURM Head Node:**
```bash
sinfo                    # Show cluster status
squeue                   # Show job queue
systemctl status slurmctld
```

**On JupyterHub Node:**
```bash
sinfo                    # Should show cluster nodes
systemctl status munge   # MUNGE authentication
systemctl status jupyterhub
```

**On Jupyter Node:**
```bash
sinfo                    # Should show cluster nodes
ls /shared/jupyter-workspace/  # Check workspace
python3 /shared/jupyter-workspace/slurm_examples.py
```

### Common Issues

**SLURM connectivity problems:**
```bash
# Check MUNGE authentication
munge -n | unmunge
systemctl restart munge

# Check SLURM configuration
scontrol show config
```

**JupyterHub job submission issues:**
```bash
# Check BatchSpawner logs
journalctl -u jupyterhub -f

# Check SLURM job logs
ls /shared/jupyterhub-logs/
```

**Shared storage issues:**
```bash
# Check NFS mount
mount | grep shared
df -h /shared

# Test file access
touch /shared/test-file
```

## 📊 Benefits Over OOD Integration

| Aspect | Open OnDemand | JupyterHub + BatchSpawner |
|--------|---------------|---------------------------|
| **Configuration** | Complex, multiple files | Simple, single Python file |
| **SLURM Integration** | Often unreliable | Native BatchSpawner support |
| **User Experience** | Web forms | Familiar Jupyter interface |
| **Customization** | Difficult | Easy Python configuration |
| **Maintenance** | High overhead | Low maintenance |
| **Research Focus** | General purpose | Optimized for scientific computing |

## 🎯 Usage Examples

### JupyterHub User Workflow

1. **Access JupyterHub**: `http://jupyterhub-ip:8000`
2. **Login**: Use system credentials
3. **Start Server**: JupyterHub submits SLURM job automatically
4. **Use Jupyter Lab**: Full-featured notebook environment
5. **Access Shared Data**: `/shared` directory available

### Jupyter Command-Line Workflow

```python
# In Jupyter notebook
from slurm_examples import submit_slurm_job, check_job_status

# Submit a job
script = """#!/bin/bash
python3 -c "print('Hello from SLURM!')"
"""

job_id = submit_slurm_job(script, "test_job")
check_job_status(job_id)
```

## 🔮 Future Enhancements

- **Resource Profiles**: Different SLURM resource configurations for different user types
- **Job Templates**: Pre-configured job templates for common research tasks
- **Monitoring Dashboard**: Real-time cluster and job monitoring
- **Auto-scaling**: Dynamic compute node scaling based on demand
- **GPU Support**: Integration with GPU-enabled compute nodes

---

**Result**: A much simpler, more reliable SLURM integration system that's easier to manage and better suited for research computing workflows!