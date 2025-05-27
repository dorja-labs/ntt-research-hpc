# NTT Research Infrastructure

A comprehensive cloud infrastructure deployment system for research computing environments, built on Google Cloud Platform using the Google Cluster Toolkit (formerly HPC Toolkit). This repository provides automated deployment and management of various research computing components including HPC clusters, Jupyter environments, Open OnDemand portals, and Kubernetes clusters.

## 🏗️ Architecture Overview

The infrastructure is organized into modular components that can be deployed independently or together:

- **Network**: Base VPC network infrastructure with subnets and firewall rules
- **Storage**: Shared NFS storage using Google Cloud Filestore
- **HPC-SLURM**: High-Performance Computing cluster with SLURM scheduler
- **HPC-PBS**: Alternative HPC cluster with PBS Professional scheduler
- **OOD**: Open OnDemand web portal for job submission and management
- **Jupyter**: Jupyter Lab server for interactive computing
- **K8s**: Kubernetes cluster for containerized workloads
- **VDI**: Virtual Desktop Infrastructure with GPU support

## 📁 Repository Structure

```
├── ctrl.sh                    # Main control script for component management
├── install.sh                 # Installation script for dependencies
├── remove.sh                  # Complete infrastructure cleanup script
├── instructions.txt           # Basic usage instructions
├── modules/                   # Terraform modules from Google Cluster Toolkit
├── ntt/                       # NTT-specific configurations and scripts
│   ├── ntt-research.yml       # Main blueprint configuration
│   ├── config-manager.sh      # Component existence checker
│   ├── hpc-slurm/            # SLURM cluster setup scripts
│   ├── hpc-pbs/              # PBS cluster setup scripts
│   ├── ood/                  # Open OnDemand configuration
│   └── jupyter/              # Jupyter server setup
├── ntt-research/             # Generated Terraform configurations
├── toolkit/                  # Google Cluster Toolkit (gcluster binary)
└── tools/                    # Additional utility scripts
```

## 🚀 Quick Start

### Development Environment (Recommended)

**🐳 DevContainer - Preferred Development Platform**

This repository includes a complete DevContainer configuration that provides a pre-configured development environment with all necessary tools and dependencies. This is the **recommended way** to work with this infrastructure.

#### Prerequisites for DevContainer
- **Docker Desktop** or **Docker Engine**
- **Visual Studio Code** with the **Dev Containers extension**
- **Google Cloud Project** with billing enabled

#### Using the DevContainer

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd ntt-research-infrastructure
   ```

2. **Open in DevContainer**:
   - Open the folder in VS Code
   - When prompted, click "Reopen in Container"
   - Or use Command Palette: `Dev Containers: Reopen in Container`

3. **The DevContainer automatically provides**:
   - Ubuntu 22.04 base environment
   - Google Cloud SDK (`gcloud`)
   - Terraform (latest version)
   - Google Cluster Toolkit (`gcluster`) - pre-compiled
   - All required dependencies (`yq`, `jq`, `curl`, `wget`)
   - Zsh with Oh My Zsh configuration
   - Git and development tools

4. **Authenticate with Google Cloud** (inside the container):
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   gcloud auth application-default login
   ```

### Alternative: Local Installation

If you prefer not to use the DevContainer:

#### Prerequisites for Local Development
1. **Google Cloud Project** with billing enabled
2. **Required APIs** enabled:
   - Compute Engine API
   - Cloud Filestore API
   - Cloud Resource Manager API
   - IAM Service Account Credentials API

3. **Sufficient Quotas** for:
   - Compute instances
   - CPUs
   - Persistent disks
   - Filestore instances

#### Local Installation Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd ntt-research-infrastructure
   ```

2. **Run the installation script**:
   ```bash
   ./install.sh
   ```
   This installs:
   - Google Cloud SDK (`gcloud`)
   - Terraform
   - Google Cluster Toolkit (`gcluster`)
   - Required dependencies (`yq`, `jq`)

3. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   gcloud auth application-default login
   ```

### Basic Usage

The main interface is the `ctrl.sh` script:

```bash
# Deploy all components
./ctrl.sh create all

# Deploy specific component
./ctrl.sh create network
./ctrl.sh create storage
./ctrl.sh create hpc-slurm

# Check status
./ctrl.sh status all
./ctrl.sh status hpc-slurm

# Update components
./ctrl.sh update hpc-slurm

# Delete components
./ctrl.sh delete hpc-slurm
./ctrl.sh delete all
```

## 📋 Component Details

### Network Component
- **Purpose**: Base VPC network infrastructure
- **Resources**:
  - VPC network (`ntt-research-network`)
  - Subnet (`ntt-research-subnet`: 10.0.0.0/24)
  - Firewall rules for component communication
- **Dependencies**: None (base component)

### Storage Component
- **Purpose**: Shared NFS storage for all compute resources
- **Resources**:
  - Google Cloud Filestore instance (1TB BASIC_HDD)
  - Mount point: `/shared`
  - Share name: `ntt_storage`
- **Dependencies**: Network

### HPC-SLURM Component
- **Purpose**: High-Performance Computing cluster with SLURM workload manager
- **Resources**:
  - 2x c2-standard-8 compute nodes
  - SLURM controller and compute daemons
  - Shared MUNGE authentication
  - NFS-mounted shared storage
- **Features**:
  - Automatic node discovery
  - Shared configuration via NFS
  - Integration with Open OnDemand
- **Dependencies**: Network, Storage

### HPC-PBS Component
- **Purpose**: Alternative HPC cluster with PBS Professional scheduler
- **Resources**:
  - 2x c2-standard-8 compute nodes
  - PBS Professional server and execution hosts
- **Dependencies**: Network, Storage

### Open OnDemand (OOD) Component
- **Purpose**: Web-based portal for HPC job submission and management
- **Resources**:
  - 1x c2-standard-4 web server
  - Apache web server with OOD portal
  - Integration with SLURM and Jupyter
- **Features**:
  - Web-based job submission
  - File management interface
  - Interactive application launcher
  - SLURM cluster integration
- **Access**: HTTP/HTTPS on ports 80/443
- **Dependencies**: Network, Storage

### Jupyter Component
- **Purpose**: Interactive computing environment
- **Resources**:
  - 1x c2-standard-4 server
  - Jupyter Lab installation
  - SLURM client for job submission
- **Features**:
  - Web-based notebook interface
  - Integration with SLURM cluster
  - Shared storage access
- **Access**: HTTP on port 8888
- **Dependencies**: Network, Storage

### Kubernetes (K8s) Component
- **Purpose**: Container orchestration platform
- **Resources**:
  - 3x c2-standard-4 nodes
  - Kubernetes cluster setup
- **Dependencies**: Network, Storage

### VDI Component
- **Purpose**: Virtual Desktop Infrastructure
- **Resources**:
  - Windows Server 2019 instances
  - NVIDIA Tesla T4 GPU acceleration
  - Remote desktop capabilities
- **Dependencies**: Network

## 🔧 Scripts and Tools

### Main Control Script (`ctrl.sh`)
The primary interface for managing infrastructure components.

**Commands**:
- `create [component]` - Deploy component(s)
- `update [component]` - Update existing component(s)
- `delete [component]` - Remove component(s)
- `status [component]` - Show component status
- `restart [component]` - Restart component services
- `logs [component]` - Show component logs
- `ssh [component]` - SSH into component instances

**Options**:
- `--project-id ID` - Specify GCP project
- `--force` - Force creation/update
- `--help` - Show help

### Installation Script (`install.sh`)
Automated installation of all required dependencies and tools.

**Features**:
- Cross-platform support (Linux, macOS)
- Dependency detection and installation
- Google Cloud SDK setup
- Terraform installation
- Cluster Toolkit compilation

### Cleanup Script (`remove.sh`)
Complete infrastructure teardown and cleanup.

**Actions**:
- Deletes all GCP resources
- Removes local Terraform state
- Cleans up remote state buckets
- Removes generated configurations

### Component Setup Scripts

Each component includes specialized setup scripts:

#### SLURM Setup (`ntt/hpc-slurm/setup.sh`)
- Configures SLURM controller and compute nodes
- Sets up MUNGE authentication
- Configures shared storage integration
- Integrates with Open OnDemand

#### OOD Setup (`ntt/ood/setup.sh`)
- Installs and configures Open OnDemand
- Sets up Apache web server
- Configures SLURM integration
- Creates user authentication

#### Jupyter Setup (`ntt/jupyter/setup.sh`)
- Installs Jupyter Lab
- Configures SLURM client
- Sets up OOD integration
- Configures shared storage access

## 🔗 Component Dependencies

The infrastructure follows a dependency hierarchy:

```
Network (base)
├── Storage
│   ├── HPC-SLURM
│   ├── HPC-PBS
│   ├── OOD
│   ├── Jupyter
│   └── K8s
└── VDI
```

**Deployment Order**:
1. Network
2. Storage
3. Compute components (HPC-SLURM, HPC-PBS, OOD, Jupyter, K8s, VDI)

**Deletion Order** (reverse):
1. Compute components
2. Storage
3. Network

## 🔐 Security and Access

### Authentication
- **Google Cloud**: Service account or user credentials
- **OOD Portal**: HTTP Basic Auth (default: ood/ood)
- **SSH Access**: GCP metadata-based SSH keys
- **SLURM**: MUNGE-based authentication

### Network Security
- **Firewall Rules**: Component-specific access controls
- **Private Networking**: Internal communication via private IPs
- **External Access**: Limited to necessary ports (SSH, HTTP/HTTPS)

### Storage Security
- **NFS**: Network-based file sharing
- **Permissions**: Standard Unix file permissions
- **Encryption**: Google Cloud encryption at rest

## 📊 Monitoring and Logging

### Built-in Monitoring
- **GCP Console**: Resource monitoring and metrics
- **Component Logs**: Startup and operation logs
- **SLURM Accounting**: Job and resource usage tracking

### Log Locations
- **Startup Logs**: `/tmp/*-startup.log` on each instance
- **SLURM Logs**: `/var/log/slurm/`
- **OOD Logs**: `/var/log/apache2/` and `/var/log/ondemand/`
- **System Logs**: Standard systemd journal

## 🛠️ Customization

### Blueprint Configuration
The main configuration is in `ntt/ntt-research.yml`:

```yaml
# Modify instance types
machine_type: c2-standard-8

# Adjust instance counts
instance_count: 4

# Change disk sizes
disk_size_gb: 500

# Modify network settings
subnet_ip: 10.0.0.0/24
```

### Component Settings
Each component can be customized by modifying:
- **Startup scripts**: In the blueprint YAML
- **Configuration files**: In `ntt/[component]/config/`
- **Setup scripts**: In `ntt/[component]/setup.sh`

### Adding New Components
1. Add component definition to `ntt/ntt-research.yml`
2. Create setup scripts in `ntt/[component]/`
3. Add post-install handler to `ctrl.sh`
4. Update documentation

## 🐛 Troubleshooting

### Common Issues

**Authentication Errors**:
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

**Quota Exceeded**:
- Check GCP quotas in Console
- Request quota increases if needed
- Reduce instance counts/sizes

**Component Startup Failures**:
```bash
# Check startup logs
gcloud compute ssh INSTANCE_NAME --command "sudo tail -f /tmp/*startup.log"

# Check component status
./ctrl.sh status COMPONENT_NAME
```

**Network Connectivity Issues**:
```bash
# Debug network connectivity
./ntt/debug-network.sh

# Test NFS connectivity
./ntt/test-nfs-workflow.sh
```

### Log Analysis
```bash
# View component logs
./ctrl.sh logs COMPONENT_NAME

# SSH into instances for debugging
./ctrl.sh ssh COMPONENT_NAME

# Check Terraform state
cd ntt-research/COMPONENT_NAME
terraform show
```

## 📚 Additional Resources

### Documentation
- [Google Cluster Toolkit Documentation](https://cloud.google.com/cluster-toolkit/docs)
- [SLURM Documentation](https://slurm.schedmd.com/documentation.html)
- [Open OnDemand Documentation](https://osc.github.io/ood-documentation/)
- [Google Cloud Documentation](https://cloud.google.com/docs)

### Examples and Tutorials
- [HPC on Google Cloud](https://cloud.google.com/solutions/hpc)
- [AI/ML Hypercomputer](https://cloud.google.com/ai-hypercomputer)
- [Cluster Toolkit Examples](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main/examples)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Guidelines
- Follow existing code style
- Add appropriate documentation
- Test all components
- Update this README for new features

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review component logs
3. Consult Google Cloud documentation
4. Open an issue in this repository

---

**Note**: This infrastructure is designed for research and development purposes. For production deployments, additional security hardening and monitoring should be implemented.