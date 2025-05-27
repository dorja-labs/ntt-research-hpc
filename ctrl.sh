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

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print help
print_help() {
    echo -e "${BLUE}HPC Toolkit Control Script${NC}"
    echo "Usage: $0 [command] [component] [options]"
    echo
    echo "Commands:"
    echo "  status [component]    Show status of all or specific component"
    echo "  create [component]    Deploy all or specific component"
    echo "  update [component]    Update all or specific component"
    echo "  delete [component]    Delete all or specific component"
    echo "  restart [component]   Restart a specific component"
    echo "  logs [component]      Show logs for a specific component"
    echo "  ssh [component]       SSH into a specific component"
    echo
    echo "Components:"
    echo "  all                   All components"
    echo "  network              Network infrastructure"
    echo "  storage              Shared Filestore storage"
    echo "  openstack            OpenStack cluster"
    echo "  jupyterhub           JupyterHub server with SLURM integration"
    echo "  hpc-slurm            HPC cluster with SLURM scheduler"
    echo "  hpc-pbs              HPC cluster with PBS scheduler"
    echo "  k8s                  Kubernetes cluster nodes"
    echo "  jupyter              Jupyter server"
    echo "  vdi                  Virtual Desktop Infrastructure"
    echo
    echo "Options:"
    echo "  --project-id ID      Specify GCP project ID"
    echo "  --force             Force creation/update even if component exists"
    echo "  --help              Show this help message"
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

# Function to show status of all resources
show_status() {
    print_status "Checking infrastructure status..."

    # Check network
    print_status "\nNetwork:"
    gcloud compute networks list --filter="name~ntt-research-network" --format="table(name,x_gcloud_subnet_mode)" 2>/dev/null || true

    # Check storage
    print_status "\nStorage:"
    gcloud filestore instances list --filter="name~ntt-research" --format="table(name,state,zone)" 2>/dev/null || true

    # Check OpenStack
    print_status "\nOpenStack Cluster:"
    gcloud compute instances list --filter="name~ntt-research-openstack" --format="table(name,status,zone)" 2>/dev/null || true

    # Check JupyterHub server
    print_status "\nJupyterHub Server:"
    gcloud compute instances list --filter="name~ntt-research-jupyterhub" --format="table(name,status,zone,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true

    # Check HPC SLURM cluster
    print_status "\nHPC SLURM Cluster Nodes:"
    gcloud compute instances list --filter="name~ntt-research-hpc-slurm" --format="table(name,status,zone)" 2>/dev/null || true

    # Check HPC PBS cluster
    print_status "\nHPC PBS Cluster Nodes:"
    gcloud compute instances list --filter="name~ntt-research-hpc-pbs" --format="table(name,status,zone)" 2>/dev/null || true

    # Check Kubernetes cluster
    print_status "\nKubernetes Cluster Nodes:"
    gcloud compute instances list --filter="name~ntt-research-k8s" --format="table(name,status,zone)" 2>/dev/null || true

    # Check Jupyter server
    print_status "\nJupyter Server:"
    gcloud compute instances list --filter="name:('ntt-research-jupyter-0')" --format="table(name,status,zone,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || {
        print_warning "No Jupyter instances found"
    }

    # Check VDI
    print_status "\nVDI Cluster:"
    gcloud compute instances list --filter="name~ntt-research-vdi" --format="table(name,status,zone)" 2>/dev/null || true
}

# Function to check if component exists
check_component_exists() {
    local component=$1
    ./ntt/config-manager.sh check-exists "$component"
}

# Function to run JupyterHub post-setup
run_jupyterhub_setup() {
    print_status "Running JupyterHub post-setup..."

    # Change to JupyterHub directory
    cd ntt/jupyterhub || {
        print_error "Failed to change to JupyterHub directory"
        return 1
    }

    # Run setup script
    if ! ./setup.sh; then
        print_error "JupyterHub setup failed"
        cd - > /dev/null
        return 1
    fi

    # Return to original directory
    cd - > /dev/null
    print_success "JupyterHub post-setup completed successfully"
}

# Function to run SLURM post-install
run_slurm_post_install() {
    print_status "Running SLURM post-install which includes OOD integration setup..."

    # Check if setup script exists
    local setup_script_path="ntt/hpc-slurm/setup.sh"
    if [ ! -f "${setup_script_path}" ]; then
        print_error "SLURM setup script not found at ${setup_script_path}"
        return 1
    fi

    # Run SLURM setup script (which now includes OOD integration)
    print_status "Executing ${setup_script_path}..."
    if ! bash "${setup_script_path}"; then
        print_error "SLURM setup script (${setup_script_path}) failed. Check its log output for details."
        return 1
    fi

    print_success "SLURM post-install (including OOD integration) completed successfully."
    print_status "Check the logs from ${setup_script_path} (locally) and from the OOD node for detailed status."
    return 0
}

# Function to run PBS post-install
run_pbs_post_install() {
    print_status "Running PBS post-install..."
    bash ntt/hpc-pbs/setup.sh
    if [ $? -ne 0 ]; then
        print_error "PBS post-install failed"
        return 1
    fi
    print_success "PBS post-install completed successfully"
}

# Function to run Kubernetes post-install
run_k8s_post_install() {
    print_status "Running Kubernetes post-install..."
    bash ntt/k8s/setup.sh
    if [ $? -ne 0 ]; then
        print_error "Kubernetes post-install failed"
        return 1
    fi
    print_success "Kubernetes post-install completed successfully"
}

# Function to run Jupyter post-install
run_jupyter_post_install() {
    print_status "Running Jupyter post-install..."
    bash ntt/jupyter/setup.sh
    if [ $? -ne 0 ]; then
        print_error "Jupyter post-install failed"
        return 1
    fi
    print_success "Jupyter post-install completed successfully"
}

# Function to run VDI post-install
run_vdi_post_install() {
    print_status "Running VDI post-install..."
    bash ntt/vdi/setup.sh
    if [ $? -ne 0 ]; then
        print_error "VDI post-install failed"
        return 1
    fi
    print_success "VDI post-install completed successfully"
}

# Map of components to their post-install functions
declare -A POST_INSTALL_HANDLERS=(
    ["jupyterhub"]="run_jupyterhub_setup"
    ["hpc-slurm"]="run_slurm_post_install"
    ["hpc-pbs"]="run_pbs_post_install"
    ["k8s"]="run_k8s_post_install"
    ["jupyter"]="run_jupyter_post_install"
    ["vdi"]="run_vdi_post_install"
)

# Function to run post-install for a component
run_post_install() {
    local component=$1
    local handler=${POST_INSTALL_HANDLERS[$component]}

    if [ -n "$handler" ]; then
        print_status "Running post-install for $component..."
        $handler
        return $?
    else
        print_warning "No post-install handler found for $component"
        return 0
    fi
}

# Function to create a component
create_component() {
    local component=$1
    local force=$2
    local blueprint="ntt/ntt-research.yml"

    # If force flag is set, delete the component first
    if [ "$force" = "--force" ]; then
        print_status "Force flag set, deleting existing component..."
        ./ctrl.sh delete "$component"
    else
        # Check if component exists
        if ./ntt/config-manager.sh check-exists "$component"; then
            print_error "Component ${component} already exists. Use --force to overwrite."
            return 1
        fi
    fi

    print_status "Creating component ${component}..."

    # Deploy the component
    print_status "Deploying $component component..."
    if [ "$component" = "all" ]; then
        gcluster deploy "$blueprint" \
            --vars "project_id=$(get_project_id),region=us-central1,zone=us-central1-a" \
            --auto-approve \
            -w
    else
        gcluster deploy "$blueprint" \
            --vars "project_id=$(get_project_id),region=us-central1,zone=us-central1-a" \
            --only "$component" \
            --auto-approve \
            -w
    fi

    # Run post-install for the component
    if [ "$component" = "all" ]; then
        for comp in "${!POST_INSTALL_HANDLERS[@]}"; do
            run_post_install "$comp"
        done
    else
        run_post_install "$component"
    fi

    print_success "Component ${component} created successfully"
}

# Function to update a specific component
update_component() {
    local component=$1
    local force=$2
    local blueprint="ntt/ntt-research.yml"
    print_status "Updating $component component..."

    # Check if component exists
    if [ "$force" != "true" ] && ! check_component_exists "$component"; then
        print_error "Component $component does not exist"
        print_status "Use create command to create the component first"
        return 1
    fi

    # Create the deployment using gcluster
    print_status "Creating updated deployment with gcluster..."
    if [ "$component" = "all" ]; then
        gcluster deploy "$blueprint" \
            --vars "project_id=$(get_project_id),region=us-central1,zone=us-central1-a" \
            --auto-approve \
            -w
    else
        gcluster deploy "$blueprint" \
            --vars "project_id=$(get_project_id),region=us-central1,zone=us-central1-a" \
            --auto-approve \
            -w \
            --only "$component"
    fi

    # Run post-install for the component
    if [ "$component" = "all" ]; then
        for comp in "${!POST_INSTALL_HANDLERS[@]}"; do
            run_post_install "$comp"
        done
    else
        run_post_install "$component"
    fi

    print_success "$component component update completed"
}

# Function to delete a component
delete_component() {
    local component=$1
    print_status "Deleting $component component..."

    # Check if component exists
    if ! ./ntt/config-manager.sh check-exists "$component"; then
        print_error "Component $component does not exist"
        return 1
    fi

    # Use gcluster for deletion
    print_status "Deleting component using gcluster..."
    if [ "$component" = "all" ]; then
        gcluster destroy "ntt-research"
    else
        gcluster destroy "ntt-research" --only "$component"
    fi

    print_success "$component component deleted successfully"
}

# Function to show status of a specific component
show_component_status() {
    local component=$1

    case $component in
        all)
            show_status
            ;;
        network)
            print_status "\nNetwork Status:"
            gcloud compute networks list --filter="name=ntt-research-network" --format="table(name,x_gcloud_subnet_mode)" 2>/dev/null || true
            ;;
        storage)
            print_status "\nStorage Status:"
            gcloud filestore instances list --filter="name~ntt-research" --format="table(name,state,zone)" 2>/dev/null || true
            ;;
        openstack)
            print_status "\nOpenStack Status:"
            gcloud compute instances list --filter="name~ntt-research-openstack" --format="table(name,status,zone)" 2>/dev/null || true
            ;;
        jupyterhub)
            print_status "\nJupyterHub Server Status:"
            gcloud compute instances list --filter="name=ntt-research-jupyterhub" --format="table(name,status,zone,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true
            ;;
        hpc-slurm)
            print_status "\nHPC SLURM Cluster Status:"
            gcloud compute instances list --filter="name~ntt-research-hpc-slurm" --format="table(name,status,zone)" 2>/dev/null || true
            ;;
        hpc-pbs)
            print_status "\nHPC PBS Cluster Status:"
            gcloud compute instances list --filter="name~ntt-research-hpc-pbs" --format="table(name,status,zone)" 2>/dev/null || true
            ;;
        k8s)
            print_status "\nKubernetes Cluster Status:"
            gcloud compute instances list --filter="name~ntt-research-k8s" --format="table(name,status,zone)" 2>/dev/null || true
            ;;
        jupyter)
            print_status "\nJupyter Server Status:"
            gcloud compute instances list --filter="name:('ntt-research-jupyter-0')" --format="table(name,status,zone,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || {
                print_warning "No Jupyter instances found"
            }
            ;;
        vdi)
            print_status "\nVDI Cluster Status:"
            gcloud compute instances list --filter="name~ntt-research-vdi" --format="table(name,status,zone)" 2>/dev/null || true
            ;;
        *)
            print_error "Unknown component: $component"
            return 1
            ;;
    esac
}


# Main script
main() {
    # Check if gcloud is installed
    check_gcloud

    # Parse command line arguments
    local command=""
    local component="all"
    local force=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            status|create|update|delete|restart|logs|ssh)
                command=$1
                if [ -n "$2" ] && [[ ! "$2" =~ ^-- ]]; then
                    component=$2
                    shift
                fi
                ;;
            --project-id)
                if [ -z "$2" ]; then
                    print_error "Project ID required"
                    exit 1
                fi
                gcloud config set project "$2"
                shift
                ;;
            --force)
                force="--force"
                ;;
            --help)
                print_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
        shift
    done

    # Execute the command
    case $command in
        status)
            show_component_status "$component"
            ;;
        create)
            create_component "$component" "$force"
            ;;
        update)
            update_component "$component" "$force"
            ;;
        delete)
            delete_component "$component"
            ;;
        restart)
            print_error "Restart command not implemented yet"
            ;;
        logs)
            print_error "Logs command not implemented yet"
            ;;
        ssh)
            print_error "SSH command not implemented yet"
            ;;
        *)
            print_error "Unknown command: $command"
            print_help
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"