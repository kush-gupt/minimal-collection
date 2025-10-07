# Building a Custom Execution Environment

This guide explains how to add the `kush_gupt.minimal_collection` collection to a custom Ansible Automation Platform Execution Environment using `ansible-builder`.

## What is an Execution Environment?

An Execution Environment (EE) is a containerized image that contains Ansible, collections, Python dependencies, and system dependencies. It provides a consistent, portable runtime for Ansible automation.

## Prerequisites

### Required Tools

1. **ansible-builder** - Tool for building execution environments
   ```bash
   pip install ansible-builder
   ```

2. **Podman** - Container runtime
   ```bash
   # On RHEL/Fedora
   sudo dnf install podman
   ```

3. **Base Image Access** - Ensure you have access to the Red Hat registry
   ```bash
   # Login to Red Hat registry
   podman login registry.redhat.io
   # Enter your Red Hat credentials
   ```

## Project Structure

Create a directory structure for your custom execution environment:

```
my-custom-ee/
├── execution-environment.yml
├── requirements.yml
└── requirements.txt (optional)
```

## Configuration Files

### 1. execution-environment.yml

This is the main configuration file for ansible-builder:

```yaml
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_steps:
  prepend_base:
    - RUN echo "Building custom EE with minimal_collection"
  
  append_final:
    - RUN ansible-galaxy collection list
    - RUN echo "Custom EE build complete"

options:
  package_manager_path: /usr/bin/microdnf
```

### 2. requirements.yml

Specify the Ansible collections to include:

```yaml
---
collections:
  # Install from Ansible Galaxy
  - name: kush_gupt.minimal_collection
    version: ">=1.0.0"
  
  # Or install from Git repository
  # - name: https://github.com/kush-gupt/minimal-collection.git
  #   type: git
  #   version: main
  
  # Add other collections as needed
  # - name: ansible.posix
  #   version: ">=1.5.0"
```

### 3. requirements.txt (Optional)

If your collection requires additional Python packages:

```
# Add Python dependencies here
# Example:
# requests>=2.28.0
# jinja2>=3.1.0
```

### 4. bindep.txt (Optional)

If you need additional system packages:

```
# Add system package dependencies here
# Example:
# git [platform:rpm]
# python3-devel [platform:rpm]
```

## Building the Execution Environment

### Step 1: Create the Configuration

Create a new directory and add the configuration files:

```bash
mkdir my-custom-ee
cd my-custom-ee

# Create execution-environment.yml (see above)
cat > execution-environment.yml <<EOF
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml

options:
  package_manager_path: /usr/bin/microdnf
EOF

# Create requirements.yml (see above)
cat > requirements.yml <<EOF
---
collections:
  - name: kush_gupt.minimal_collection
    version: ">=1.0.0"
EOF
```

### Step 2: Build the Image

Run ansible-builder to create your custom execution environment:

```bash
# Build with Podman (default)
ansible-builder build --tag my-org/custom-ee-minimal:1.0.0 --verbosity 3

# Or build with Docker
ansible-builder build --tag my-org/custom-ee-minimal:1.0.0 --container-runtime docker --verbosity 3
```

### Step 3: Verify the Build

Check that the image was created successfully:

```bash
# List images
podman images | grep custom-ee-minimal

# Verify the collection is installed
podman run --rm my-org/custom-ee-minimal:1.0.0 ansible-galaxy collection list | grep minimal_collection
```

Expected output:
```
kush_gupt.minimal_collection    1.0.0
```

## Using the Custom Execution Environment

### Option 1: Local Testing with ansible-navigator

```bash
# Install ansible-navigator
pip install ansible-navigator

# Create a test playbook
cat > test-playbook.yml <<EOF
---
- name: Test minimal_collection modules
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Display collection info
      ansible.builtin.debug:
        msg: "Using kush_gupt.minimal_collection"
    
    - name: Example sysctl usage (check mode)
      kush_gupt.minimal_collection.sysctl:
        name: vm.swappiness
        value: "10"
        state: present
      check_mode: yes
EOF

# Run with custom EE
ansible-navigator run test-playbook.yml \
  --execution-environment-image my-org/custom-ee-minimal:1.0.0 \
  --mode stdout
```

### Option 2: Push to Registry for Ansible Controller

```bash
# Tag the image for your registry
podman tag my-org/custom-ee-minimal:1.0.0 your-registry.com/my-org/custom-ee-minimal:1.0.0

# Login to your registry
podman login your-registry.com

# Push the image
podman push your-registry.com/my-org/custom-ee-minimal:1.0.0
```

Then in Ansible Controller/AAP:
1. Navigate to **Administration** → **Execution Environments**
2. Click **Add**
3. Provide:
   - **Name**: Custom EE with Minimal Collection
   - **Image**: `your-registry.com/my-org/custom-ee-minimal:1.0.0`
   - **Pull**: Always or If not present
4. Save and associate with your Job Templates

### Option 3: Use in AWX/Ansible Controller Job Template

1. Create/Edit a Job Template
2. In the **Execution Environment** dropdown, select your custom EE
3. Use the modules in your playbooks:

```yaml
---
- name: Configure system parameters
  hosts: all
  become: yes
  tasks:
    - name: Set kernel parameter
      kush_gupt.minimal_collection.sysctl:
        name: vm.swappiness
        value: 10
        state: present
        reload: yes
    
    - name: Update configuration file
      kush_gupt.minimal_collection.ini_file:
        path: /etc/myapp/config.ini
        section: database
        option: host
        value: db.example.com
        state: present
```

## Advanced Configuration

### Multi-Stage Build for Smaller Images

```yaml
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml

additional_build_steps:
  prepend_final:
    - RUN microdnf clean all
    - RUN rm -rf /var/cache/dnf /tmp/*

options:
  package_manager_path: /usr/bin/microdnf
```

### Installing from a Private Git Repository

If you want to install directly from your GitHub repository:

```yaml
---
collections:
  - name: https://github.com/kush-gupt/minimal-collection.git
    type: git
    version: main
  
  # Or with authentication
  - name: git+https://{{ github_token }}@github.com/kush-gupt/minimal-collection.git
    type: git
    version: main
```

### Installing from Local Development Copy

For testing during development:

```yaml
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

additional_build_files:
  - src: ../kush_gupt-minimal_collection-1.0.0.tar.gz
    dest: collections/

additional_build_steps:
  append_final:
    - COPY _build/collections/kush_gupt-minimal_collection-1.0.0.tar.gz /tmp/
    - RUN ansible-galaxy collection install /tmp/kush_gupt-minimal_collection-1.0.0.tar.gz

options:
  package_manager_path: /usr/bin/microdnf
```

## Troubleshooting

### Build Failures

If the build fails, check:

1. **Registry Access**: Ensure you're logged in to registry.redhat.io
   ```bash
   podman login registry.redhat.io
   ```

2. **Collection Availability**: Verify the collection is published to Galaxy
   ```bash
   ansible-galaxy collection install kush_gupt.minimal_collection
   ```

3. **Build Logs**: Use verbose mode to see detailed logs
   ```bash
   ansible-builder build --verbosity 3
   ```

### Collection Not Found at Runtime

If ansible-navigator can't find the collection:

1. Verify it's in the image:
   ```bash
   podman run --rm my-org/custom-ee-minimal:1.0.0 \
     ansible-galaxy collection list
   ```

2. Check the collection path:
   ```bash
   podman run --rm my-org/custom-ee-minimal:1.0.0 \
     ansible-config dump | grep COLLECTIONS_PATHS
   ```

### Permission Issues

If you encounter permission errors in AAP/Controller:

1. Ensure the image is accessible from the Controller nodes
2. Check that the registry credentials are configured in Controller
3. Verify the image pull policy settings

## Best Practices

1. **Version Pinning**: Always pin collection versions in `requirements.yml`
   ```yaml
   - name: kush_gupt.minimal_collection
     version: "1.0.0"  # Specific version instead of ">=1.0.0"
   ```

2. **Image Tagging**: Use semantic versioning for your EE images
   ```bash
   my-org/custom-ee-minimal:1.0.0
   my-org/custom-ee-minimal:1.0
   my-org/custom-ee-minimal:latest
   ```

3. **Documentation**: Include a README in your EE project describing what's included

4. **Testing**: Test the EE locally before pushing to production

5. **Size Optimization**: Remove unnecessary packages to keep images small

6. **Security Scanning**: Regularly scan your EE images for vulnerabilities
   ```bash
   podman scan my-org/custom-ee-minimal:1.0.0
   ```

## Example: Complete Working Setup

Here's a complete example you can use right away:

```bash
# Create project directory
mkdir -p ~/ansible-ee/minimal-collection-ee
cd ~/ansible-ee/minimal-collection-ee

# Create execution-environment.yml
cat > execution-environment.yml <<'EOF'
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml

additional_build_steps:
  append_final:
    - RUN ansible-galaxy collection list | grep minimal_collection

options:
  package_manager_path: /usr/bin/microdnf
EOF

# Create requirements.yml
cat > requirements.yml <<'EOF'
---
collections:
  - name: kush_gupt.minimal_collection
    version: ">=1.0.0"
EOF

# Build the EE
ansible-builder build -t custom-ee-minimal:1.0.0 -v 3

# Test it
ansible-navigator run --help \
  --execution-environment-image custom-ee-minimal:1.0.0
```

## Additional Resources

- [Ansible Builder Documentation](https://ansible-builder.readthedocs.io/)
- [Execution Environment Guide](https://docs.ansible.com/automation-controller/latest/html/userguide/execution_environments.html)
- [Red Hat Ansible Automation Platform](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)
- [Collection Repository](https://github.com/kush-gupt/minimal-collection)
- [Ansible Galaxy Page](https://galaxy.ansible.com/kush_gupt/minimal_collection)

## Support

For issues with:
- **This collection**: https://github.com/kush-gupt/minimal-collection/issues
- **Ansible Builder**: https://github.com/ansible/ansible-builder/issues
- **AAP/Execution Environments**: Red Hat Support Portal

