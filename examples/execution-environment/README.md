# Execution Environment Example

This directory contains example files for building a custom Execution Environment with the `kush_gupt.minimal_collection` collection.

## Prerequisites

1. Install ansible-builder:
   ```bash
   pip install ansible-builder
   ```

2. Have Podman or Docker installed

3. (Optional) Login to Red Hat registry if using RHEL base images:
   ```bash
   podman login registry.redhat.io
   ```
   
   **Note**: For testing without Red Hat credentials, use the CentOS Stream configuration (see below).

## Quick Start

### Option 1: Using Red Hat EE Base Image (Requires Registry Access)

1. Navigate to this directory:
   ```bash
   cd examples/execution-environment
   ```

2. Build the execution environment:
   ```bash
   ansible-builder build --tag my-custom-ee:1.0.0 --verbosity 3
   ```

3. Verify the build:
   ```bash
   podman images | grep my-custom-ee
   podman run --rm my-custom-ee:1.0.0 ansible-galaxy collection list
   ```

### Option 2: Using CentOS Stream Base Image (No Authentication Required)

Perfect for CI/CD and testing without Red Hat registry credentials:

1. Navigate to this directory:
   ```bash
   cd examples/execution-environment
   ```

2. Build using CentOS Stream configuration:
   ```bash
   ansible-builder build \
     --file execution-environment-centos.yml \
     --tag my-custom-ee-centos:1.0.0 \
     --verbosity 3
   ```

3. Verify the build:
   ```bash
   podman images | grep my-custom-ee-centos
   podman run --rm my-custom-ee-centos:1.0.0 ansible-galaxy collection list
   ```

### Test with a Playbook

```bash
# Option 1: With ansible-navigator
ansible-navigator run test-playbook.yml \
  --execution-environment-image my-custom-ee:1.0.0 \
  --mode stdout

# Option 2: Direct podman run
podman run --rm my-custom-ee:1.0.0 \
  ansible-playbook test-playbook.yml
```

### Or Use the Build Script

```bash
# Basic build
./build.sh

# Build with custom tag
./build.sh --tag my-org/custom-ee:2.0.0

# Build using CentOS Stream
ansible-builder build -f execution-environment-centos.yml -t custom-ee-centos:1.0.0
```

## Files

### Configuration Files

- **`execution-environment.yml`** - Main configuration using Red Hat EE base image
- **`execution-environment-centos.yml`** - Alternative configuration using CentOS Stream (for CI/CD)
- **`requirements.yml`** - Ansible collections to include
- **`requirements-ee.txt`** - Python dependencies for the EE
- **`bindep.txt`** - System package dependencies

### Scripts and Tests

- **`build.sh`** - Automated build script with options
- **`test-playbook.yml`** - Example playbook for testing the collection modules
- **`README.md`** - This file

### Which Configuration to Use?

| Configuration | Use Case | Requires Auth |
|--------------|----------|---------------|
| `execution-environment.yml` | Production on AAP/RHEL | Yes (registry.redhat.io) |
| `execution-environment-centos.yml` | CI/CD, Testing, Development | No |

**GitHub CI**: The repository includes automated testing using the CentOS Stream configuration. See [`.github/workflows/test-ee-build.yml`](../../.github/workflows/test-ee-build.yml)

## Customization

### Change the Base Image

Edit `execution-environment.yml`:

```yaml
images:
  base_image:
    name: your-base-image:tag
```

### Add More Collections

Edit `requirements.yml`:

```yaml
collections:
  - name: kush_gupt.minimal_collection
    version: ">=1.0.0"
  - name: your.other.collection
    version: ">=1.0.0"
```

### Add Python Dependencies

Create `requirements.txt`:

```
requests>=2.28.0
jinja2>=3.1.0
```

Then reference it in `execution-environment.yml`:

```yaml
dependencies:
  galaxy: requirements.yml
  python: requirements.txt
```

### Add System Packages

Create `bindep.txt`:

```
git [platform:rpm]
python3-devel [platform:rpm]
```

Then reference it in `execution-environment.yml`:

```yaml
dependencies:
  galaxy: requirements.yml
  system: bindep.txt
```

## Pushing to a Registry

```bash
# Tag for your registry
podman tag my-custom-ee:1.0.0 your-registry.com/my-org/custom-ee:1.0.0

# Login to your registry
podman login your-registry.com

# Push
podman push your-registry.com/my-org/custom-ee:1.0.0
```

## Using with Ansible Controller/AWX

1. Navigate to **Administration** → **Execution Environments**
2. Click **Add**
3. Name: `Custom EE with Minimal Collection`
4. Image: `your-registry.com/my-org/custom-ee:1.0.0`
5. Save

Then select this EE in your Job Templates.

## Troubleshooting

### Build fails with "registry.redhat.io unauthorized"

Make sure you're logged in:
```bash
podman login registry.redhat.io
```

### Collection not found

Verify it's published to Galaxy:
```bash
ansible-galaxy collection install kush_gupt.minimal_collection
```

### Check what's in the image

```bash
podman run --rm -it my-custom-ee:1.0.0 /bin/bash
# Inside container:
ansible-galaxy collection list
ansible --version
```

For more detailed documentation, see [EXECUTION_ENVIRONMENT.md](../../EXECUTION_ENVIRONMENT.md) in the repository root.

