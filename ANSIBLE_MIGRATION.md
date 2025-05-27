# Ansible Migration Guide

## 🎯 **Why Migrate to Ansible?**

Our current shell scripts have grown complex and difficult to maintain. Ansible provides significant advantages:

### **Current Shell Script Problems:**
- ❌ **Complex Error Handling**: Manual status checks and error propagation
- ❌ **Not Idempotent**: Running scripts multiple times can cause issues
- ❌ **Hard to Test**: Difficult to test individual components
- ❌ **State Management**: No built-in rollback or state tracking
- ❌ **Maintenance**: Growing complexity with nested conditionals
- ❌ **Debugging**: Hard to troubleshoot when things go wrong

### **Ansible Advantages:**
- ✅ **Idempotent**: Safe to run multiple times - only changes what's needed
- ✅ **Declarative**: Describe desired state, not steps
- ✅ **Error Handling**: Automatic rollback and better error reporting
- ✅ **Modular**: Reusable roles and tasks
- ✅ **Testing**: Built-in dry-run mode with `--check`
- ✅ **Documentation**: Self-documenting YAML structure
- ✅ **Parallel Execution**: Run tasks on multiple hosts simultaneously
- ✅ **Inventory Management**: Better host and group management

## 📁 **New Ansible Structure**

```
ansible/
├── inventory/
│   ├── hosts.yml              # Static inventory template
│   └── dynamic_hosts.yml      # Generated from GCP instances
├── roles/
│   ├── common/                # Shared tasks (NFS, packages)
│   │   └── tasks/main.yml
│   ├── slurm/                 # SLURM cluster configuration
│   │   ├── tasks/main.yml
│   │   └── templates/slurm.conf.j2
│   ├── jupyterhub/            # JupyterHub setup
│   │   ├── tasks/main.yml
│   │   ├── templates/jupyterhub_config.py.j2
│   │   └── handlers/main.yml
│   ├── jupyter/               # Standalone Jupyter
│   ├── pbs/                   # PBS cluster
│   └── kubernetes/            # K8s cluster
├── scripts/
│   └── run-ansible.sh        # Wrapper script for integration
├── site.yml                  # Main playbook
└── ansible.cfg               # Ansible configuration
```

## 🚀 **Migration Strategy**

### **Phase 1: Parallel Implementation** (Current)
- ✅ Create Ansible roles alongside existing shell scripts
- ✅ Test Ansible playbooks in development
- ✅ Keep shell scripts as fallback

### **Phase 2: Integration** (Next)
- 🔄 Update `ctrl.sh` to use Ansible for post-setup
- 🔄 Add `--use-ansible` flag for gradual migration
- 🔄 Compare results between shell and Ansible

### **Phase 3: Full Migration** (Future)
- 🔄 Replace shell scripts entirely with Ansible
- 🔄 Remove old shell scripts
- 🔄 Update documentation

## 🛠️ **Usage Examples**

### **Using the Ansible Wrapper**

```bash
# Deploy all components with Ansible
./ansible/scripts/run-ansible.sh all

# Deploy only SLURM cluster
./ansible/scripts/run-ansible.sh slurm

# Deploy JupyterHub
./ansible/scripts/run-ansible.sh jupyterhub

# Dry-run to see what would change
./ansible/scripts/run-ansible.sh all check
```

### **Direct Ansible Commands**

```bash
# Ansible is automatically installed via install.sh or DevContainer
# If needed manually: pip3 install ansible

# Run full deployment
ansible-playbook -i ansible/inventory/dynamic_hosts.yml ansible/site.yml

# Deploy specific component
ansible-playbook -i ansible/inventory/dynamic_hosts.yml ansible/site.yml --limit slurm_cluster

# Dry-run mode (see what would change)
ansible-playbook -i ansible/inventory/dynamic_hosts.yml ansible/site.yml --check --diff

# Run with verbose output
ansible-playbook -i ansible/inventory/dynamic_hosts.yml ansible/site.yml -vvv
```

### **Integration with ctrl.sh**

```bash
# Use Ansible for post-setup (when implemented)
./ctrl.sh create hpc-slurm --use-ansible

# Traditional shell script method (current default)
./ctrl.sh create hpc-slurm
```

## 📋 **Ansible Role Details**

### **Common Role** (`ansible/roles/common/`)
Handles shared tasks for all nodes:
- Package installation and updates
- NFS mount setup with fallback
- Directory creation
- Basic system configuration

### **SLURM Role** (`ansible/roles/slurm/`)
Replaces complex SLURM shell scripts:
- **Idempotent**: Safe to run multiple times
- **Dynamic Config**: Generates `slurm.conf` from inventory
- **Proper Ordering**: Head node setup before compute nodes
- **Error Handling**: Automatic service verification

**Key Improvements:**
```yaml
# Wait for shared config (instead of complex bash loops)
- name: Wait for SLURM config to be available
  wait_for:
    path: "{{ slurm_conf_path }}"
    timeout: 600

# Idempotent service management
- name: Start and enable slurmd
  systemd:
    name: slurmd
    state: started
    enabled: true
```

### **JupyterHub Role** (`ansible/roles/jupyterhub/`)
Simplifies JupyterHub deployment:
- **Package Management**: Handles Python, Node.js, and scientific packages
- **Configuration Templates**: Dynamic config generation
- **Service Management**: Proper systemd integration
- **SLURM Integration**: Automatic BatchSpawner setup

## 🔧 **Configuration Management**

### **Dynamic Inventory**
The `run-ansible.sh` script automatically generates inventory from GCP:

```yaml
# Generated from: gcloud compute instances list
slurm_head:
  hosts:
    ntt-research-hpc-slurm-0:
      ansible_host: 34.123.45.67
      slurm_role: controller
```

### **Variable Management**
Centralized configuration in inventory:

```yaml
vars:
  # Automatically detected
  filestore_ip: "{{ detected_from_gcp }}"
  project_id: "{{ gcloud_project }}"

  # Infrastructure settings
  slurm_cluster_name: ntt-research-slurm
  nfs_mount_point: /shared
```

## 🧪 **Testing and Validation**

### **Dry-Run Mode**
```bash
# See what would change without making changes
ansible-playbook -i inventory/dynamic_hosts.yml site.yml --check --diff
```

### **Component Testing**
```bash
# Test only SLURM configuration
ansible-playbook -i inventory/dynamic_hosts.yml site.yml --limit slurm_cluster --check

# Test only common tasks
ansible-playbook -i inventory/dynamic_hosts.yml site.yml --tags common --check
```

### **Verification Tasks**
Each role includes verification:
```yaml
- name: Verify SLURM services are running
  systemd:
    name: "{{ item }}"
    state: started
  loop:
    - munge
    - slurmd
```

## 📊 **Comparison: Shell vs Ansible**

### **SLURM Setup Comparison**

**Shell Script (Current):**
```bash
# 180+ lines of complex bash
if [ ! -f "$SHARED_SLURM_CONF" ] || [ ! -f "$SHARED_MUNGE_KEY" ]; then
    if [ $ELAPSED_WAIT -ge $MAX_WAIT_SECONDS ]; then
        echo "ERROR: SLURM config files not found after ${MAX_WAIT_SECONDS} seconds"
        exit 1
    fi
    sleep $WAIT_INTERVAL
    ((ELAPSED_WAIT += WAIT_INTERVAL))
done
```

**Ansible (New):**
```yaml
# Simple, declarative, idempotent
- name: Wait for SLURM config to be available
  wait_for:
    path: "{{ slurm_conf_path }}"
    timeout: 600
  when: slurm_role != 'controller'
```

### **Error Handling Comparison**

**Shell Script:**
```bash
check_status() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "✓ $message"
    else
        log "✗ $message (Failed with exit code: $exit_code)"
        exit $exit_code
    fi
}
```

**Ansible:**
```yaml
# Automatic error handling, rollback, and reporting
# No manual error checking needed
- name: Install SLURM packages
  apt:
    name: [slurm-wlm, munge]
    state: present
  # Ansible handles errors automatically
```

## 🔄 **Migration Benefits**

### **Immediate Benefits:**
1. **Reliability**: Idempotent operations prevent configuration drift
2. **Debugging**: Better error messages and logging
3. **Testing**: Dry-run mode for safe testing
4. **Documentation**: Self-documenting YAML

### **Long-term Benefits:**
1. **Maintainability**: Easier to read and modify
2. **Scalability**: Easy to add new nodes or components
3. **Consistency**: Guaranteed consistent configuration
4. **Automation**: Better CI/CD integration

## 🚦 **Migration Timeline**

### **Week 1-2: Foundation**
- ✅ Create basic Ansible structure
- ✅ Implement common and SLURM roles
- ✅ Test in development environment

### **Week 3-4: Integration**
- 🔄 Update ctrl.sh with `--use-ansible` flag
- 🔄 Implement remaining roles (JupyterHub, Jupyter, PBS)
- 🔄 Add comprehensive testing

### **Week 5-6: Validation**
- 🔄 Side-by-side testing (shell vs Ansible)
- 🔄 Performance comparison
- 🔄 Documentation updates

### **Week 7-8: Full Migration**
- 🔄 Make Ansible the default
- 🔄 Remove old shell scripts
- 🔄 Update all documentation

## 📚 **Learning Resources**

### **Ansible Basics:**
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [YAML Syntax](https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html)

### **Our Implementation:**
- `ansible/roles/*/tasks/main.yml` - Task definitions
- `ansible/inventory/hosts.yml` - Host definitions
- `ansible/site.yml` - Main playbook

## 🆘 **Troubleshooting**

### **Common Issues:**

**Ansible not found:**
```bash
# Ansible should be automatically installed via install.sh or DevContainer
# If missing, install manually:
pip3 install --user ansible

# Add to PATH if needed:
export PATH="$HOME/.local/bin:$PATH"

# Or use system package manager:
sudo apt-get install ansible
```

**SSH connection issues:**
```bash
# Test connectivity
ansible all -i inventory/dynamic_hosts.yml -m ping

# Debug SSH
ansible all -i inventory/dynamic_hosts.yml -m ping -vvv
```

**Inventory issues:**
```bash
# Regenerate dynamic inventory
./ansible/scripts/run-ansible.sh all check

# Verify inventory
ansible-inventory -i inventory/dynamic_hosts.yml --list
```

## 🎯 **Next Steps**

1. **Try the Ansible setup:**
   ```bash
   ./ansible/scripts/run-ansible.sh slurm check
   ```

2. **Compare with shell scripts:**
   - Deploy with shell scripts
   - Deploy with Ansible
   - Compare results and performance

3. **Provide feedback:**
   - What works well?
   - What needs improvement?
   - Any missing features?

The Ansible migration represents a significant improvement in our infrastructure management capabilities, providing better reliability, maintainability, and scalability for the NTT Research Infrastructure.