# Minimal Ansible Collection

A minimal Ansible collection containing essential system configuration modules.

## Description

This collection provides two essential modules for system configuration:

- **sysctl**: Manage kernel parameters via sysctl (from ansible.posix)
- **ini_file**: Manage INI file entries (from community.general)

## Installation

You can install this collection using the `ansible-galaxy` CLI:

```bash
ansible-galaxy collection install kush_gupt.minimal_collection
```

Or include it in your `requirements.yml`:

```yaml
collections:
  - name: kush_gupt.minimal_collection
    version: ">=1.0.0"
```

## Modules

### sysctl

Manage kernel parameters via sysctl.

**Example:**

```yaml
- name: Set kernel parameter
  kush_gupt.minimal_collection.sysctl:
    name: vm.swappiness
    value: 10
    state: present
    reload: yes
```

### ini_file

Manage INI file entries.

**Example:**

```yaml
- name: Set INI file value
  kush_gupt.minimal_collection.ini_file:
    path: /etc/myapp/config.ini
    section: database
    option: host
    value: localhost
```

## Requirements

- Ansible >= 2.9.10

## Using with Execution Environments

This collection can be added to custom Ansible Automation Platform Execution Environments. See the [Execution Environment Guide](EXECUTION_ENVIRONMENT.md) for detailed instructions on:

- Building a custom EE with ansible-builder
- Testing and deploying your custom EE
- Ready-to-use examples in [`examples/execution-environment/`](examples/execution-environment/)

Quick start:
```bash
cd examples/execution-environment
ansible-builder build --tag my-custom-ee:1.0.0
```

## License

GPL-3.0-or-later

## Author Information

This collection was created to provide a minimal, focused set of system configuration modules.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## Support

For issues and questions, please open an issue on the [GitHub repository](https://github.com/kush-gupt/minimal-collection/issues).

