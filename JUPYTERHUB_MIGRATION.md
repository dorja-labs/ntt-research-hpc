# Migration from Open OnDemand to JupyterHub

## 🔄 Why We Replaced Open OnDemand

Based on user feedback about **configuration complexity** and **difficulty managing SLURM integration**, we've replaced Open OnDemand (OOD) with **JupyterHub + BatchSpawner**.

### Problems with Open OnDemand:
- ❌ **Complex configuration** - Difficult to customize and maintain
- ❌ **SLURM integration issues** - Unreliable cluster registration
- ❌ **Configuration overhead** - Multiple config files and complex setup
- ❌ **Limited research focus** - More general-purpose than research-optimized

### Advantages of JupyterHub + BatchSpawner:
- ✅ **Simple configuration** - Single config file, straightforward setup
- ✅ **Reliable SLURM integration** - BatchSpawner "just works" with SLURM
- ✅ **Research-focused** - Perfect for bio and physical sciences
- ✅ **Better user experience** - Familiar Jupyter interface
- ✅ **Easier to extend** - Simple to add new packages and tools
- ✅ **Active community** - Well-maintained and widely used

## 🚀 What Changed

### Infrastructure Changes
- **Component name**: `ood` → `jupyterhub`
- **Service port**: 80/443 → 8000
- **Instance name**: `ntt-research-ood-0` → `ntt-research-jupyterhub-0`
- **Setup script**: `ntt/ood/setup.sh` → `ntt/jupyterhub/setup.sh`

### User Experience Changes
- **Access URL**: `http://ood-ip/` → `http://jupyterhub-ip:8000`
- **Authentication**: HTTP Basic Auth → PAM (system users)
- **Interface**: OOD web portal → JupyterHub + Jupyter Lab
- **Job submission**: OOD forms → Jupyter notebooks with SLURM magic commands

## 🛠️ How to Use JupyterHub

### Deployment
```bash
# Deploy JupyterHub instead of OOD
./ctrl.sh create jupyterhub

# Check status
./ctrl.sh status jupyterhub
```

### User Access
1. **Navigate to JupyterHub**: `http://JUPYTERHUB_IP:8000`
2. **Login**: Use your system username/password (ubuntu, root, etc.)
3. **Start server**: JupyterHub will submit a SLURM job for your session
4. **Use Jupyter Lab**: Full-featured notebook environment

### SLURM Integration
JupyterHub automatically submits SLURM jobs for user sessions:

```bash
# Each user session runs as a SLURM job
#SBATCH --job-name=jupyterhub-username
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00
```

### Using SLURM from Jupyter
Users can submit additional SLURM jobs from within Jupyter:

```python
# In a Jupyter notebook
import subprocess

# Submit a SLURM job
result = subprocess.run([
    'sbatch', '--partition=debug', '--time=1:00:00',
    '--wrap', 'python my_script.py'
], capture_output=True, text=True)

print(f"Job ID: {result.stdout.strip()}")
```

## 📦 Pre-installed Packages

JupyterHub comes with scientific packages for both bio and physical sciences:

### General Scientific Computing
- `numpy`, `pandas`, `matplotlib`, `seaborn`
- `scipy`, `scikit-learn`
- `dask`, `distributed`
- `plotly`, `bokeh`

### Bioinformatics
- `biopython`
- `bioinfokit`

### Physical Sciences
- Standard Python scientific stack
- Easy to add domain-specific packages

## 🔧 Configuration

### Simple Configuration File
JupyterHub uses a single Python configuration file:

```python
# /etc/jupyterhub/jupyterhub_config.py

# SLURM integration - much simpler than OOD!
c.JupyterHub.spawner_class = 'batchspawner.SlurmSpawner'
c.SlurmSpawner.req_partition = 'debug'
c.SlurmSpawner.req_memory = '4G'
c.SlurmSpawner.req_runtime = '4:00:00'

# User directories on shared storage
c.Spawner.notebook_dir = '/shared/notebooks/{username}'
```

### Adding New Packages
```bash
# SSH into JupyterHub instance
gcloud compute ssh ntt-research-jupyterhub-0 --zone=us-central1-a

# Install packages globally
sudo pip3 install new-package

# Or add to startup script for automatic installation
```

## 🔍 Troubleshooting

### Check JupyterHub Status
```bash
# From control machine
./ctrl.sh status jupyterhub

# On JupyterHub instance
sudo systemctl status jupyterhub
sudo journalctl -u jupyterhub -f
```

### Check SLURM Integration
```bash
# On JupyterHub instance
sinfo  # Should show SLURM cluster
squeue # Should show running jobs
```

### User Session Issues
```bash
# Check user job logs
ls /shared/jupyterhub-logs/
cat /shared/jupyterhub-logs/username-*.out
```

## 🎯 For Research Computing

### Bioinformatics Workflows
```python
# Example: DNA sequence analysis
from Bio import SeqIO
import pandas as pd

# Load sequences from shared storage
sequences = SeqIO.parse('/shared/data/sequences.fasta', 'fasta')

# Process with SLURM job submission
# Submit analysis jobs to cluster
```

### Physical Sciences
```python
# Example: Numerical simulation
import numpy as np
import matplotlib.pyplot as plt
from dask.distributed import Client

# Connect to Dask cluster (can be configured)
# Run large-scale computations
```

## 📈 Performance Benefits

### Resource Efficiency
- **Dynamic allocation**: Resources allocated only when users are active
- **SLURM scheduling**: Proper resource management and queuing
- **Shared storage**: Efficient data sharing between users

### Scalability
- **Multi-user**: Supports many concurrent users
- **Elastic**: Scales with SLURM cluster capacity
- **Configurable**: Easy to adjust resource limits

## 🔄 Migration Checklist

If migrating from an existing OOD setup:

- [ ] Deploy new JupyterHub component
- [ ] Test SLURM integration
- [ ] Migrate user data to `/shared/notebooks/`
- [ ] Update user documentation
- [ ] Train users on Jupyter interface
- [ ] Remove old OOD component

## 🆘 Support

### Getting Help
1. **Check logs**: JupyterHub logs are much clearer than OOD
2. **Test SLURM**: Verify SLURM cluster is working
3. **User issues**: Most issues are resolved by restarting user servers

### Common Issues
- **Login problems**: Check PAM authentication
- **Server won't start**: Check SLURM cluster status
- **Package missing**: Install via pip3 on JupyterHub instance

---

**Result**: A much simpler, more reliable research computing platform that's easier to manage and better suited for scientific computing workflows!