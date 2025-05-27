#!/bin/bash

# Exit on error
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

# Get project ID
get_project_id() {
    gcloud config get-value project 2>/dev/null
}

# Delete all resources manually
delete_all_resources() {
    print_status "Deleting all resources..."

    # Delete Jupyter resources
    print_status "Deleting Jupyter resources..."
    gcloud compute instances list --filter="name=ntt-research-jupyter" --format="get(name,zone)" | while read -r name zone; do
        if [ -n "$name" ]; then
            print_status "Deleting Jupyter instance: $name in zone $zone"
            gcloud compute instances delete "$name" --zone="$zone" --quiet || true
        fi
    done
    gcloud compute firewall-rules list --filter="name~ntt-research-jupyter-fw-" --format="get(name)" | while read -r rule_name; do
        if [ -n "$rule_name" ]; then
            print_status "Deleting Jupyter firewall rule: $rule_name"
            gcloud compute firewall-rules delete "$rule_name" --quiet || true
        fi
    done

    # Delete K8s resources
    print_status "Deleting K8s resources..."
    gcloud compute instances list --filter="name~ntt-research-k8s" --format="get(name,zone)" | while read -r name zone; do
        if [ -n "$name" ]; then
            print_status "Deleting K8s instance: $name in zone $zone"
            gcloud compute instances delete "$name" --zone="$zone" --quiet || true
        fi
    done
    gcloud compute firewall-rules list --filter="name~ntt-research-k8s-fw-" --format="get(name)" | while read -r rule_name; do
        if [ -n "$rule_name" ]; then
            print_status "Deleting K8s firewall rule: $rule_name"
            gcloud compute firewall-rules delete "$rule_name" --quiet || true
        fi
    done

    # Delete HPC resources
    print_status "Deleting HPC resources..."
    gcloud compute instances list --filter="name~ntt-research-hpc" --format="get(name,zone)" | while read -r name zone; do
        if [ -n "$name" ]; then
            print_status "Deleting HPC instance: $name in zone $zone"
            gcloud compute instances delete "$name" --zone="$zone" --quiet || true
        fi
    done
    gcloud compute firewall-rules list --filter="name~ntt-research-hpc-fw-" --format="get(name)" | while read -r rule_name; do
        if [ -n "$rule_name" ]; then
            print_status "Deleting HPC firewall rule: $rule_name"
            gcloud compute firewall-rules delete "$rule_name" --quiet || true
        fi
    done

    # Delete OOD resources
    print_status "Deleting OOD resources..."
    gcloud compute instances list --filter="name=ntt-research-ood" --format="get(name,zone)" | while read -r name zone; do
        if [ -n "$name" ]; then
            print_status "Deleting OOD instance: $name in zone $zone"
            gcloud compute instances delete "$name" --zone="$zone" --quiet || true
        fi
    done
    gcloud compute firewall-rules list --filter="name~ntt-research-ood-fw-" --format="get(name)" | while read -r rule_name; do
        if [ -n "$rule_name" ]; then
            print_status "Deleting OOD firewall rule: $rule_name"
            gcloud compute firewall-rules delete "$rule_name" --quiet || true
        fi
    done

    # Delete Storage resources
    print_status "Deleting Storage resources..."
    gcloud filestore instances list --filter="name=ntt-research-fs" --format="get(name,zone)" | while read -r fs_name fs_zone; do
        if [ -n "$fs_name" ]; then
            print_status "Deleting Filestore: $fs_name in zone $fs_zone"
            gcloud filestore instances delete "$fs_name" --zone="$fs_zone" --quiet || true
        fi
    done

    # Delete Network resources
    print_status "Deleting Network resources..."
    # Delete Cloud NAT
    for router_name in "ntt-research-router" "ntt-research-network-router"; do
        if gcloud compute routers describe "$router_name" --region=us-central1 &>/dev/null; then
            gcloud compute routers nats list --router="$router_name" --region=us-central1 --format="get(name)" | while read -r nat_name; do
                if [ -n "$nat_name" ]; then
                    print_status "Deleting NAT: $nat_name"
                    gcloud compute routers nats delete "$nat_name" --router="$router_name" --region=us-central1 --quiet || true
                fi
            done
        fi
    done

    # Delete Cloud Router
    for router_name in "ntt-research-router" "ntt-research-network-router"; do
        if gcloud compute routers describe "$router_name" --region=us-central1 &>/dev/null; then
            print_status "Deleting router: $router_name"
            gcloud compute routers delete "$router_name" --region=us-central1 --quiet || true
        fi
    done

    # Delete IP addresses
    gcloud compute addresses list --filter="name~ntt-research-network-nat-ips" --format="get(name,region)" | while read -r ip_name region; do
        if [ -n "$ip_name" ]; then
            print_status "Deleting IP: $ip_name in region $region"
            gcloud compute addresses delete "$ip_name" --region="$region" --quiet || true
        fi
    done

    # Delete Subnets
    gcloud compute networks subnets list --network=ntt-research-network --format="get(name,region)" | while read -r subnet_name region; do
        if [ -n "$subnet_name" ]; then
            print_status "Deleting subnet: $subnet_name in region $region"
            gcloud compute networks subnets delete "$subnet_name" --region="$region" --quiet || true
        fi
    done

    # Delete all Firewall Rules
    gcloud compute firewall-rules list --filter="network=ntt-research-network" --format="get(name)" | while read -r rule_name; do
        if [ -n "$rule_name" ]; then
            print_status "Deleting firewall rule: $rule_name"
            gcloud compute firewall-rules delete "$rule_name" --quiet || true
        fi
    done

    # Delete Network
    if gcloud compute networks describe ntt-research-network &>/dev/null; then
        print_status "Deleting network: ntt-research-network"
        gcloud compute networks delete ntt-research-network --quiet || true
    fi
}

# Remove all local Terraform state and config
clean_local_tf() {
    print_status "Removing local Terraform state and config..."
    rm -rf ntt-research/.terraform*
    rm -rf ntt-research/terraform.tfstate*
    rm -rf ntt-research/terraform.tfvars*
    rm -rf ntt-research/terraform.log*
    rm -rf ntt-research/.terraform*
    rm -rf ntt-research/shared
    rm -rf ntt-research/components
    rm -rf ntt-research/terraform*
    rm -rf ntt-research/backend.tf
    rm -rf ntt-research/.terraform.lock.hcl
    rm -rf ntt-research/.terraform
}

# Remove remote Terraform state from GCS bucket
clean_remote_tf() {
    local bucket_name="ntt-research-terraform-state"
    print_status "Removing remote Terraform state from GCS bucket $bucket_name..."
    if gsutil ls "gs://$bucket_name" &>/dev/null; then
        gsutil -m rm -r "gs://$bucket_name/terraform/state/**" || true
        gsutil rb "gs://$bucket_name" || true
        print_success "Remote Terraform state bucket deleted."
    else
        print_status "No remote Terraform state bucket found."
    fi
}

# Main execution
print_status "Starting full cleanup of all components and Terraform state..."
delete_all_resources
clean_local_tf
clean_remote_tf
print_success "All components and Terraform state have been deleted. Project is now clean."