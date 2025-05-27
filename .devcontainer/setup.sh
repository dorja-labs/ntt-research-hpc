#!/bin/bash
set -e

# Install build essentials and architecture-specific packages if not present
if ! dpkg -l | grep -q build-essential; then
    echo "Installing build essentials and architecture-specific packages..."
    sudo apt-get update && sudo apt-get install -y \
        build-essential \
        gcc \
        g++ \
        libc6-dev \
        && sudo rm -rf /var/lib/apt/lists/*
fi

# Set build environment variables
export CGO_ENABLED=1
export GOARCH=arm64
export GOOS=linux
export CC=gcc
export CXX=g++

# Add build environment variables to .zshrc if not already present
if ! grep -q "CGO_ENABLED=1" ~/.zshrc; then
    echo 'export CGO_ENABLED=1' >> ~/.zshrc
    echo 'export GOARCH=arm64' >> ~/.zshrc
    echo 'export GOOS=linux' >> ~/.zshrc
    echo 'export CC=gcc' >> ~/.zshrc
    echo 'export CXX=g++' >> ~/.zshrc
fi

# Set up Git configuration if not already set
if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "VSCode Dev Container"
fi

if [ -z "$(git config --global user.email)" ]; then
    git config --global user.email "vscode@devcontainer"
fi

# Install Oh My Zsh if it doesn't exist
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed at $HOME/.oh-my-zsh"
fi

# Install zsh plugins if they don't exist
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Install zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
    echo "zsh-autosuggestions is already installed"
fi

# Install zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
    echo "zsh-syntax-highlighting is already installed"
fi

# Install Go if not present
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    curl -OL https://go.dev/dl/go1.23.0.linux-arm64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.23.0.linux-arm64.tar.gz
    rm go1.23.0.linux-arm64.tar.gz

    # Set Go environment variables
    echo 'export GOROOT=/usr/local/go' >> ~/.zshrc
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.zshrc
    echo 'export CGO_ENABLED=1' >> ~/.zshrc
    echo 'export GOARCH=arm64' >> ~/.zshrc
    echo 'export GOOS=linux' >> ~/.zshrc
    echo 'export CC=gcc' >> ~/.zshrc
    echo 'export CXX=g++' >> ~/.zshrc

    # Source the environment variables for current session
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    export CGO_ENABLED=1
    export GOARCH=arm64
    export GOOS=linux
    export CC=gcc
    export CXX=g++
else
    echo "Go is already installed"
fi

# Install Packer if not present
if ! command -v packer &> /dev/null; then
    echo "Installing Packer..."
    PACKER_VERSION="1.9.4"  # Latest stable version as of now
    curl -fsSL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_arm64.zip -o /tmp/packer.zip
    sudo unzip /tmp/packer.zip -d /usr/local/bin/
    rm /tmp/packer.zip
else
    # Check if installed version is older than 1.7.9
    INSTALLED_VERSION=$(packer version | grep -oP 'Packer v\K[0-9.]+')
    if [ "$(printf '%s\n' "1.7.9" "$INSTALLED_VERSION" | sort -V | head -n1)" = "1.7.9" ]; then
        echo "Updating Packer to newer version..."
        PACKER_VERSION="1.9.4"  # Latest stable version as of now
        curl -fsSL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_arm64.zip -o /tmp/packer.zip
        sudo unzip -o /tmp/packer.zip -d /usr/local/bin/
        rm /tmp/packer.zip
    else
        echo "Packer is already installed with version ${INSTALLED_VERSION}"
    fi
fi

# Install yq if not present
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    curl -L "https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_arm64" -o /tmp/yq
    sudo mv /tmp/yq /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
else
    echo "yq is already installed"
fi

# Install Terraform if not present
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    curl -L "https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_arm64.zip" -o /tmp/terraform.zip
    sudo unzip /tmp/terraform.zip -d /usr/local/bin/
    rm /tmp/terraform.zip
else
    echo "Terraform is already installed"
fi

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl is already installed"
fi

# Install Google Cloud CLI if not present
if ! command -v gcloud &> /dev/null; then
    echo "Installing Google Cloud CLI..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin
else
    echo "Google Cloud CLI is already installed"
fi

# Set up Google Cloud authentication
echo "Setting up Google Cloud authentication..."
if [ -f "/workspaces/ntt-research/.devcontainer/gcp-key.json" ]; then
    echo "Using existing service account key..."
    gcloud auth activate-service-account --key-file=/workspaces/ntt-research/.devcontainer/gcp-key.json
    gcloud config set project $(gcloud config get-value project)
else
    echo "WARNING: No service account key found at /workspaces/ntt-research/.devcontainer/gcp-key.json"
    echo "Please place your service account key file at that location and rebuild the container"
    echo "You can create a service account key from the Google Cloud Console:"
    echo "1. Go to IAM & Admin > Service Accounts"
    echo "2. Create a new service account or select an existing one"
    echo "3. Create a new key (JSON format)"
    echo "4. Save the key file as gcp-key.json in the .devcontainer directory"
fi

# Make scripts executable
chmod +x /workspaces/cluster-toolkit/ctrl.sh \
    /workspaces/cluster-toolkit/ntt/config-manager.sh \
    /workspaces/cluster-toolkit/remove.sh

# Update .zshrc with plugins if not already configured
if ! grep -q "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" ~/.zshrc; then
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
fi