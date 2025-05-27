# NTT Research Infrastructure

A comprehensive cloud infrastructure deployment system for research computing environments, built on Google Cloud Platform using the Google Cluster Toolkit (formerly HPC Toolkit). This repository provides automated deployment and management of various research computing components including HPC clusters, Jupyter environments, Open OnDemand portals, and Kubernetes clusters.

## 🏗️ Architecture Overview

The infrastructure is organized into modular components that can be deployed independently or together:

- **Network**: Base VPC network infrastructure with subnets and firewall rules
- **Storage**: Shared NFS storage using Google Cloud Filestore
- **HPC-SLURM**: High-Performance Computing cluster with SLURM scheduler
- **HPC-PBS**: Alternative HPC cluster with PBS Professional scheduler
- **JupyterHub**: Multi-user Jupyter environment with SLURM integration for interactive computing
- **Jupyter**: Jupyter Lab server for interactive computing
- **K8s**: Kubernetes cluster for containerized workloads
- **VDI**: Virtual Desktop Infrastructure with GPU support

## 📁 Repository Structure

```
├── .devcontainer/            # DevContainer configuration (recommended dev environment)
│   ├── Dockerfile            # Container image definition
│   ├── devcontainer.json     # VS Code DevContainer configuration
│   └── setup.sh              # Container setup script
├── ctrl.sh                   # Main control script for component management
├── install.sh                # Installation script for dependencies (local setup)
├── remove.sh                 # Complete infrastructure cleanup script
├── instructions.txt          # Basic usage instructions
├── modules/                  # Terraform modules from Google Cluster Toolkit
├── ntt/                      # NTT-specific configurations and scripts
│   ├── ntt-research.yml      # Main blueprint configuration
│   ├── config-manager.sh     # Component existence checker
│   ├── hpc-slurm/           # SLURM cluster setup scripts
│   ├── hpc-pbs/             # PBS cluster setup scripts
│   ├── ood/                 # Open OnDemand configuration
│   └── jupyter/             # Jupyter server setup
├── ntt-research/            # Generated Terraform configurations
├── toolkit/                 # Google Cluster Toolkit (gcluster binary)
└── tools/                   # Additional utility scripts
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

### JupyterHub Component
- **Purpose**: Multi-user Jupyter environment with SLURM batch job integration
- **Resources**:
  - 1x c2-standard-4 web server
  - JupyterHub with BatchSpawner
  - Pre-installed scientific Python packages
- **Features**:
  - Multi-user Jupyter Lab environment
  - SLURM job submission via BatchSpawner
  - Shared storage integration
  - Pre-configured for bio and physical sciences
  - Much simpler configuration than Open OnDemand
- **Access**: HTTP on port 8000
- **Dependencies**: Network, Storage
- **Advantages**: Easier to configure, reliable SLURM integration, better for research computing

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

## 🐳 DevContainer Development Environment

### Why Use the DevContainer?

The DevContainer provides a **consistent, reproducible development environment** that eliminates "works on my machine" issues. It's the **recommended approach** for:

- **New contributors** - Get started immediately without complex setup
- **Cross-platform development** - Same environment on Windows, macOS, and Linux
- **CI/CD consistency** - Match your local environment with automated pipelines
- **Dependency management** - All tools pre-installed and configured

### DevContainer Features

#### Pre-installed Tools
- **Google Cloud SDK** (`gcloud`) - Latest version with all components
- **Terraform** - Latest stable version
- **Google Cluster Toolkit** (`gcluster`) - Pre-compiled and ready to use
- **Development Tools**: `git`, `curl`, `wget`, `jq`, `yq`, `vim`, `nano`
- **Shell Environment**: Zsh with Oh My Zsh and useful plugins

#### Container Specifications
- **Base Image**: Ubuntu 22.04 LTS
- **Architecture**: Multi-arch support (amd64/arm64)
- **User**: Non-root user with sudo access
- **Workspace**: `/workspaces/ntt-research`

#### VS Code Integration
- **Extensions**: Automatically installs recommended extensions
- **Settings**: Pre-configured for optimal development experience
- **Terminal**: Integrated terminal with proper shell configuration

### DevContainer Configuration Files

#### `.devcontainer/devcontainer.json`
Main configuration file that defines:
- Container image and build settings
- VS Code extensions and settings
- Port forwarding and volume mounts
- Post-creation commands

#### `.devcontainer/Dockerfile`
Container image definition with:
- Base Ubuntu 22.04 image
- System package installations
- User configuration and permissions

#### `.devcontainer/setup.sh`
Post-creation setup script that:
- Installs and configures development tools
- Sets up shell environment
- Configures Git and other tools
- Compiles Google Cluster Toolkit

### Working with the DevContainer

#### First Time Setup
1. **Install Prerequisites**:
   - Docker Desktop (Windows/macOS) or Docker Engine (Linux)
   - Visual Studio Code
   - Dev Containers extension for VS Code

2. **Open Repository**:
   ```bash
   git clone <repository-url>
   code ntt-research-infrastructure
   ```

3. **Start DevContainer**:
   - VS Code will detect the DevContainer configuration
   - Click "Reopen in Container" when prompted
   - Or use Command Palette: `Dev Containers: Reopen in Container`

#### Daily Workflow
```bash
# Inside the DevContainer terminal

# Authenticate with Google Cloud (one-time setup)
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login

# Use the infrastructure tools
./ctrl.sh status all
./ctrl.sh create network
gcluster --version

# All tools are pre-installed and ready to use!
```

#### Customizing the DevContainer

You can customize the DevContainer by modifying:

- **`.devcontainer/devcontainer.json`** - VS Code settings, extensions, port forwarding
- **`.devcontainer/Dockerfile`** - Additional system packages or tools
- **`.devcontainer/setup.sh`** - Additional setup commands or configurations

#### Troubleshooting DevContainer Issues

**Container won't start**:
```bash
# Rebuild the container
# Command Palette: "Dev Containers: Rebuild Container"
```

**Missing tools**:
```bash
# Re-run setup script
./.devcontainer/setup.sh
```

**Permission issues**:
```bash
# Check user permissions
whoami
sudo -l
```

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
│   ├── JupyterHub
│   ├── Jupyter
│   └── K8s
└── VDI
```

**Deployment Order**:
1. Network
2. Storage
3. Compute components (HPC-SLURM, HPC-PBS, JupyterHub, Jupyter, K8s, VDI)

**Deletion Order** (reverse):
1. Compute components
2. Storage
3. Network

## 🔐 Security and Access

### Authentication
- **Google Cloud**: Service account or user credentials
- **JupyterHub**: PAM authentication (system users)
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
- **JupyterHub Logs**: `/var/log/jupyterhub/`
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

We welcome contributions! The DevContainer makes it easy to get started with development.

### Getting Started with Development

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ntt-research-infrastructure.git
   cd ntt-research-infrastructure
   ```
3. **Open in DevContainer** (Recommended):
   - Open in VS Code
   - Click "Reopen in Container" when prompted
   - All tools will be automatically available!

4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

5. **Make your changes** using the pre-configured environment
6. **Test thoroughly** using the available tools
7. **Submit a pull request**

### Development Guidelines

#### Code Standards
- Follow existing code style and conventions
- Use meaningful commit messages
- Add appropriate documentation for new features
- Test all components before submitting

#### Testing Your Changes
```bash
# Inside the DevContainer

# Test infrastructure deployment
./ctrl.sh create network
./ctrl.sh status network

# Validate Terraform configurations
cd ntt-research/network
terraform validate

# Test scripts
./ntt/test-nfs-workflow.sh
```

#### Documentation Updates
- Update this README for new features or changes
- Add inline comments for complex scripts
- Update component documentation in `ntt/` directories
- Include troubleshooting information for new components

### Development Environment Benefits

Using the DevContainer for development provides:
- **Consistent Environment**: Same tools and versions for all contributors
- **Quick Setup**: No need to install dependencies locally
- **Isolation**: Development environment doesn't affect your host system
- **Pre-configured Tools**: All necessary tools ready to use immediately

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

**Copyright 2024 NTT Data Australia Pty Ltd**

This project incorporates several open source components including:
- Google Cluster Toolkit (Apache 2.0)
- Terraform (Mozilla Public License 2.0)
- SLURM Workload Manager (GPL v2.0)
- Open OnDemand (MIT License)
- Jupyter (BSD 3-Clause)
- PBS Professional (AGPL v3.0)
- Kubernetes (Apache 2.0)

See the [LICENSE](LICENSE) file for complete third-party software notices and license information.

## 🆘 Support

For issues and questions:
1. **Use the DevContainer** - Eliminates most environment-related issues
2. Check the troubleshooting section
3. Review component logs
4. Consult Google Cloud documentation
5. Open an issue in this repository

### Getting Help

**Environment Issues**: If you're having problems with dependencies or tool versions, try using the DevContainer which provides a known-good environment.

**Infrastructure Issues**: Use the built-in debugging tools:
```bash
# Inside DevContainer
./ctrl.sh status all
./ntt/debug-network.sh
./ntt/test-nfs-workflow.sh
```

---

**Note**: This infrastructure is designed for research and development purposes. For production deployments, additional security hardening and monitoring should be implemented.

**Recommended**: Use the DevContainer for the best development and operational experience.