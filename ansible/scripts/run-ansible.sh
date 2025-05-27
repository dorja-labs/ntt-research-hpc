#!/bin/bash

# Ansible wrapper script for NTT Research Infrastructure
# This script integrates Ansible playbooks with the existing ctrl.sh workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[ANSIBLE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ANSIBLE]${NC} $1"
}

print_error() {
    echo -e "${RED}[ANSIBLE]${NC} $1"
}

# Function to check if Ansible is installed
check_ansible() {
    if ! command -v ansible >/dev/null 2>&1; then
        print_error "Ansible not found. Installing..."
        pip3 install ansible
    fi

    if ! command -v ansible-playbook >/dev/null 2>&1; then
        print_error "ansible-playbook not found. Please install Ansible properly."
        exit 1
    fi

    print_success "Ansible is available"
}

# Function to generate dynamic inventory
generate_inventory() {
    print_status "Generating dynamic inventory from GCP instances..."

    local inventory_file="ansible/inventory/dynamic_hosts.yml"
    local temp_file=$(mktemp)

    # Get instance information from GCP
    cat > "$temp_file" << 'EOF'
---
all:
  children:
    ntt_research:
      children:
        slurm_cluster:
          children:
            slurm_head:
              hosts:
EOF

    # Get SLURM head node
    if gcloud compute instances describe ntt-research-hpc-slurm-0 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet >/dev/null 2>&1; then
        SLURM_HEAD_IP=$(gcloud compute instances describe ntt-research-hpc-slurm-0 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
        cat >> "$temp_file" << EOF
                ntt-research-hpc-slurm-0:
                  ansible_host: ${SLURM_HEAD_IP}
                  slurm_role: controller
                  slurm_node_type: head
EOF
    fi

    cat >> "$temp_file" << 'EOF'
            slurm_compute:
              hosts:
EOF

    # Get SLURM compute nodes
    if gcloud compute instances describe ntt-research-hpc-slurm-1 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet >/dev/null 2>&1; then
        SLURM_COMPUTE_IP=$(gcloud compute instances describe ntt-research-hpc-slurm-1 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
        cat >> "$temp_file" << EOF
                ntt-research-hpc-slurm-1:
                  ansible_host: ${SLURM_COMPUTE_IP}
                  slurm_role: compute
                  slurm_node_type: compute
EOF
    fi

    # Add other components...
    cat >> "$temp_file" << 'EOF'
        jupyterhub_nodes:
          hosts:
EOF

    if gcloud compute instances describe ntt-research-jupyterhub-0 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet >/dev/null 2>&1; then
        JUPYTERHUB_IP=$(gcloud compute instances describe ntt-research-jupyterhub-0 --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)
        cat >> "$temp_file" << EOF
            ntt-research-jupyterhub-0:
              ansible_host: ${JUPYTERHUB_IP}
              jupyterhub_type: server
EOF
    fi

    # Add global variables
    FILESTORE_IP=$(gcloud filestore instances describe ntt-research-fs --zone=us-central1-a --format='get(networks[0].ipAddresses[0])' --quiet 2>/dev/null || echo "10.74.215.42")

    cat >> "$temp_file" << EOF

  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    ansible_python_interpreter: /usr/bin/python3

    # Infrastructure variables
    project_id: $(gcloud config get-value project)
    region: us-central1
    zone: us-central1-a

    # NFS/Storage variables
    filestore_ip: ${FILESTORE_IP}
    nfs_share_name: ntt_storage
    nfs_mount_point: /shared

    # SLURM variables
    slurm_cluster_name: ntt-research-slurm
    munge_key_path: /shared/slurm-config/munge.key
    slurm_conf_path: /shared/slurm-config/slurm.conf
EOF

    mv "$temp_file" "$inventory_file"
    print_success "Dynamic inventory generated: $inventory_file"
}

# Function to run Ansible playbook
run_playbook() {
    local component=$1
    local action=${2:-"deploy"}

    check_ansible
    generate_inventory

    local playbook_args=""
    local inventory_file="ansible/inventory/dynamic_hosts.yml"

    case $component in
        "all")
            playbook_args="ansible/site.yml"
            ;;
        "slurm"|"hpc-slurm")
            playbook_args="ansible/site.yml --limit slurm_cluster"
            ;;
        "jupyterhub")
            playbook_args="ansible/site.yml --limit jupyterhub_nodes"
            ;;
        "jupyter")
            playbook_args="ansible/site.yml --limit jupyter_nodes"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac

    print_status "Running Ansible playbook for $component..."

    # Run the playbook
    ansible-playbook \
        -i "$inventory_file" \
        $playbook_args \
        --become \
        --become-method=sudo \
        -v

    if [ $? -eq 0 ]; then
        print_success "Ansible playbook completed successfully for $component"
    else
        print_error "Ansible playbook failed for $component"
        exit 1
    fi
}

# Main function
main() {
    local component=${1:-"all"}
    local action=${2:-"deploy"}

    case $action in
        "deploy"|"configure"|"setup")
            run_playbook "$component" "$action"
            ;;
        "check")
            check_ansible
            generate_inventory
            ansible-playbook -i ansible/inventory/dynamic_hosts.yml ansible/site.yml --check --diff
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Usage: $0 <component> [deploy|check]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"