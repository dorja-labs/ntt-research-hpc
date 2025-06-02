#!/bin/bash

# Exit on error
set -e

# Function to print status messages
print_status() {
    echo -e "\033[1;33m==>\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m==>\033[0m $1"
}

# Function to check if a component exists in GCP
check_exists() {
    local component=$1

    case $component in
        network)
            print_status "Checking network in GCP..."
            if ! gcloud compute networks describe ntt-research-network &>/dev/null; then
                print_status "Network 'ntt-research-network' not found in GCP"
                return 1
            fi
            ;;
        storage)
            print_status "Checking Filestore instance..."
            if ! gcloud filestore instances describe ntt-research-fs --zone=us-central1-a &>/dev/null; then
                print_status "Filestore instance not found in GCP"
                return 1
            fi
            ;;
        ood)
            print_status "Checking OOD server..."
            if ! gcloud compute instances describe ntt-research-ood-0 --zone=us-central1-a &>/dev/null; then
                print_status "OOD server not found in GCP"
                return 1
            fi
            ;;
        hpc-slurm)
            print_status "Checking HPC SLURM cluster..."
            if ! gcloud compute instances list --filter="name~ntt-research-hpc-slurm" --format="table(name)" | grep -q "ntt-research-hpc-slurm"; then
                print_status "HPC SLURM cluster not found in GCP"
                return 1
            fi
            ;;
        hpc-pbs)
            print_status "Checking HPC PBS cluster..."
            if ! gcloud compute instances list --filter="name~ntt-research-hpc-pbs" --format="table(name)" | grep -q "ntt-research-hpc-pbs"; then
                print_status "HPC PBS cluster not found in GCP"
                return 1
            fi
            ;;
        jupyter)
            print_status "Checking Jupyter server..."
            if ! gcloud compute instances describe ntt-research-jupyter-0 --zone=us-central1-a &>/dev/null; then
                print_status "Jupyter server not found in GCP"
                return 1
            fi
            ;;
        jupyterhub)
            print_status "Checking JupyterHub server..."
            if ! gcloud compute instances describe ntt-research-jupyterhub-0 --zone=us-central1-a &>/dev/null; then
                print_status "JupyterHub server not found in GCP"
                return 1
            fi
            ;;
        *)
            print_error "Unknown component: $component"
            return 1
            ;;
    esac

    return 0
}

# Function to get project ID
get_project_id() {
    gcloud config get-value project
}

# Function to get component directory
get_component_dir() {
    echo "ntt-research"
}

# Main script
case "$1" in
    check-exists)
        check_exists "$2"
        ;;
    get-project-id)
        get_project_id
        ;;
    get-dir)
        get_component_dir
        ;;
    *)
        print_error "Unknown command: $1"
        exit 1
        ;;
esac