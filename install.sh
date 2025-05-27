#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "\033[1;34m==>\033[0m $1"
}

# Function to print success messages
print_success() {
    echo -e "\033[1;32m==>\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m==>\033[0m $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        # Use ID_LIKE if available, otherwise use ID
        if [ -n "$ID_LIKE" ]; then
            OS=$(echo "$ID_LIKE" | cut -d' ' -f1)
        else
            OS=$ID
        fi
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi

    # Normalize OS name
    case "$OS" in
        *debian*)
            OS="debian"
            ;;
        *ubuntu*)
            OS="ubuntu"
            ;;
        *linux*)
            OS="linux"
            ;;
    esac

    echo "$OS"
}

# Function to install yq
install_yq() {
    print_status "Checking yq installation..."

    if command_exists yq; then
        print_success "yq is already installed"
        return 0
    fi

    print_status "Installing yq..."

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac

    # Download and install yq
    YQ_VERSION="v4.35.1"  # Latest stable version
    YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}"

    if ! curl -L "$YQ_URL" -o /tmp/yq; then
        print_error "Failed to download yq"
        return 1
    fi

    if ! sudo mv /tmp/yq /usr/local/bin/yq; then
        print_error "Failed to move yq to /usr/local/bin"
        return 1
    fi

    if ! sudo chmod +x /usr/local/bin/yq; then
        print_error "Failed to make yq executable"
        return 1
    fi

    print_success "yq installed successfully"
}

# Function to install Google Cloud SDK
install_gcloud() {
    print_status "Installing Google Cloud SDK..."

    # Check if gcloud is already installed
    if command_exists gcloud; then
        print_status "Google Cloud SDK is already installed"
        return 0
    fi

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
            curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
            sudo apt-get update && sudo apt-get install -y google-cloud-sdk
        elif [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS
            sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
            sudo yum install -y google-cloud-sdk
        else
            print_error "Unsupported Linux distribution"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install --cask google-cloud-sdk
    else
        print_error "Unsupported operating system"
        exit 1
    fi

    print_success "Google Cloud SDK installed successfully"
}

# Function to install Terraform
install_terraform() {
    print_status "Installing Terraform..."

    # Check if terraform is already installed
    if command_exists terraform; then
        print_status "Terraform is already installed"
        return 0
    fi

    # Get the latest version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | cut -d'"' -f4)

    # Download and install Terraform
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -L "https://releases.hashicorp.com/terraform/${LATEST_VERSION#v}/terraform_${LATEST_VERSION#v}_linux_amd64.zip" -o terraform.zip
        unzip terraform.zip
        sudo mv terraform /usr/local/bin/
        rm terraform.zip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl -L "https://releases.hashicorp.com/terraform/${LATEST_VERSION#v}/terraform_${LATEST_VERSION#v}_darwin_amd64.zip" -o terraform.zip
        unzip terraform.zip
        sudo mv terraform /usr/local/bin/
        rm terraform.zip
    else
        print_error "Unsupported operating system"
        exit 1
    fi

    print_success "Terraform installed successfully"
}

# Function to install gcluster
install_gcluster() {
    print_status "Installing gcluster..."

    # Check if gcluster is already installed
    if command_exists gcluster; then
        print_status "gcluster is already installed"
        return 0
    fi

    # Create toolkit directory if it doesn't exist
    if [ ! -d "toolkit" ]; then
        print_status "Cloning cluster-toolkit repository..."
        if ! git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git toolkit; then
            print_error "Failed to clone repository"
            return 1
        fi

        # Add toolkit to .gitignore if not already there
        if [ ! -f ".gitignore" ]; then
            echo "toolkit/" > .gitignore
        elif ! grep -q "^toolkit/$" .gitignore; then
            echo "toolkit/" >> .gitignore
        fi
    fi

    cd toolkit

    # Check if Go is installed
    if ! command_exists go; then
        print_error "Go is required to build gcluster. Please install Go first."
        cd - > /dev/null
        return 1
    fi

    print_status "Building gcluster..."
    if ! go build -o gcluster cmd/gcluster/main.go; then
        print_error "Failed to build gcluster"
        cd - > /dev/null
        return 1
    fi

    print_status "Installing gcluster..."
    if ! sudo mv gcluster /usr/local/bin/; then
        print_error "Failed to install gcluster"
        cd - > /dev/null
        return 1
    fi

    # Clean up
    cd - > /dev/null

    # Verify installation
    if ! command_exists gcluster; then
        print_error "gcluster installation failed"
        return 1
    fi

    print_success "gcluster installed successfully"
}

# Function to make scripts executable
make_scripts_executable() {
    print_status "Making scripts executable..."

    local scripts=(
        "ctrl.sh"
        "ntt/config-manager.sh"
        "remove.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if ! chmod +x "$script"; then
                print_error "Failed to make $script executable"
                return 1
            fi
            print_success "Made $script executable"
        else
            print_error "Script not found: $script"
            return 1
        fi
    done
}

# Function to check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi

    # Check if running on a supported OS
    OS=$(detect_os)
    print_status "Detected OS: $OS"

    # List of supported OS patterns
    local supported_os=("debian" "ubuntu" "linux")
    local is_supported=false

    for supported in "${supported_os[@]}"; do
        if [ "$OS" = "$supported" ]; then
            is_supported=true
            break
        fi
    done

    if [ "$is_supported" = false ]; then
        print_error "Unsupported operating system: $OS"
        print_error "This script currently supports: ${supported_os[*]}"
        exit 1
    fi

    print_success "OS $OS is supported"

    # Check for required commands
    print_status "Checking required commands..."
    local required_commands=("curl" "wget" "gpg" "apt-get")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
        print_success "Found $cmd"
    done

    print_success "System requirements met"
}

# Function to setup GCP project
setup_gcp_project() {
    print_status "Setting up GCP project..."

    # Check if user is logged in
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_status "Please log in to Google Cloud..."
        gcloud auth login
    fi

    # List available projects
    print_status "Available projects:"
    gcloud projects list --format="table(projectId,name)"

    # Ask for project ID
    read -p "Enter the project ID to use: " PROJECT_ID

    # Set the project
    gcloud config set project "$PROJECT_ID"

    # List of APIs to enable
    local apis=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "iam.googleapis.com"
        "file.googleapis.com"
    )

    # Enable APIs
    print_status "Enabling required APIs..."
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        if gcloud services enable "$api" 2>/dev/null; then
            print_success "Enabled $api"
        else
            print_warning "Could not enable $api (this may be normal if the API is not available in your region)"
        fi
    done

    print_success "GCP project setup completed"
}

# Function to check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud >/dev/null 2>&1; then
        print_error "gcloud command not found. Please install Google Cloud SDK."
        exit 1
    fi
}

# Function to get project ID
get_project_id() {
    local project_id
    project_id=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$project_id" ]; then
        print_error "No project ID found. Please set your project ID using --project-id option."
        exit 1
    fi
    echo "$project_id"
}

# Function to create Terraform state bucket
create_terraform_state_bucket() {
    local project_id=$1
    local bucket_name="ntt-research-terraform-state"
    local location="us-central1"

    print_status "Creating Terraform state bucket..."

    # Check if bucket exists
    if gsutil ls "gs://$bucket_name" &>/dev/null; then
        print_status "Bucket $bucket_name already exists"
        return 0
    fi

    # Create bucket
    if ! gsutil mb -p "$project_id" -l "$location" "gs://$bucket_name"; then
        print_error "Failed to create bucket"
        exit 1
    fi

    # Enable versioning
    if ! gsutil versioning set on "gs://$bucket_name"; then
        print_error "Failed to enable versioning"
        exit 1
    fi

    # Set bucket labels
    if ! gsutil label ch -l "purpose:terraform-state" -l "environment:production" "gs://$bucket_name"; then
        print_error "Failed to set bucket labels"
        exit 1
    fi

    print_success "Terraform state bucket created successfully"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check for required commands
    local required_commands=("terraform" "gcloud" "gcluster")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            print_error "$cmd is not installed"
            return 1
        fi
    done

    # Check if gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_error "gcloud is not authenticated"
        print_status "Please run: gcloud auth login"
        return 1
    fi

    # Check if gcloud project is set
    if ! gcloud config get-value project &>/dev/null; then
        print_error "gcloud project is not set"
        print_status "Please run: gcloud config set project <PROJECT_ID>"
        return 1
    fi

    print_success "All prerequisites met"
    return 0
}

# Function to create ntt-research directory
create_ntt_research_dir() {
    print_status "Creating ntt-research directory structure..."

    # Create base directories
    mkdir -p ntt-research

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used for local development
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore lock files
.terraform.lock.hcl

# Ignore Mac/OSX files
.DS_Store

# Ignore IDE files
.idea/
.vscode/
*.swp
*.swo

# Ignore temporary files
*.tmp
*.temp
*.bak

# Ignore log files
*.log

# Ignore environment files
.env
.env.*

# Ignore node modules
node_modules/

# Ignore Python virtual environments
venv/
env/
ENV/

# Ignore compiled Python files
__pycache__/
*.py[cod]
*$py.class

# Ignore Jupyter Notebook checkpoints
.ipynb_checkpoints

# Ignore Terraform workspace files
terraform.tfstate.d/

# Ignore gcluster generated files
*.yaml
!ntt/configs/ntt-research.yaml
EOF

    # Create instructions.txt
    cat > instructions.txt << 'EOF'
NTT Research Infrastructure Setup

This directory contains the Terraform configuration for the NTT Research infrastructure.
The infrastructure is organized into components, each with its own workspace.

Available Components:
- network: Base network infrastructure
- storage: Filestore instance for shared storage
- ood: Open OnDemand server
- hpc: HPC cluster
- k8s: Kubernetes cluster
- jupyter: Jupyter server

Usage:
1. Create a component:
   ./ctrl.sh create <component>

2. Delete a component:
   ./ctrl.sh delete <component>

3. List components:
   ./ctrl.sh list

Component Dependencies:
- storage depends on network
- ood depends on network and storage
- hpc/k8s/jupyter depend on network and storage

Notes:
- Each component has its own Terraform workspace
- Components are created in the correct order based on dependencies
- Use --force to overwrite existing components
- The network component requires special handling for deletion
EOF

    print_success "Created directory structure"
}

# Main installation process
main() {
    print_status "Starting NTT Research infrastructure installation..."

    # Check system requirements
    check_system_requirements

    # Install required tools
    install_yq
    install_gcloud
    install_terraform
    install_gcluster

    # Setup GCP project
    setup_gcp_project

    # Create directory structure
    create_ntt_research_dir

    # Make scripts executable
    make_scripts_executable

    print_success "Installation completed successfully"
    print_status "Please review instructions.txt for next steps"
}

# Run main function
main