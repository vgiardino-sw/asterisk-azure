# Ansible - LiveKit SIP Configuration

This folder configures the VM provisioned by Terraform and deploys LiveKit SIP services via Ansible roles.

## Files

| File / Folder | Purpose |
|---|---|
| `inventory/hosts.yml.example` | Inventory template for target VM |
| `group_vars/livekit-sip.yml.example` | Runtime variable template for LiveKit SIP |
| `livekit-site.yml` | Main playbook |
| `requirements.yml` | Required Ansible collections |
| `roles/` | `livekit_common`, `livekit_certbot`, `livekit_compose` |

---

## Prerequisites

### Install Ansible on WSL (Ubuntu)

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install "ansible-core>=2.16,<2.18"
ansible --version
```

### Ensure SSH key permissions in WSL

If your key is stored on `C:\Users\...`, copy it into WSL and fix permissions:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<your-user>/.ssh/livekit_vm_ed25519 ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/livekit_vm_ed25519
```

---

## Setup Steps

### 1. Apply Terraform and collect outputs

Run Terraform in `../terraform` and note the VM public IP and FQDN from the outputs.

### 2. Prepare inventory and vars

Copy templates:

```bash
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
cp ansible/group_vars/livekit-sip.yml.example ansible/group_vars/livekit-sip.yml
```

Fill `hosts.yml` with the VM connection details:

```yaml
all:
  hosts:
    livekit_sip_vm:
      ansible_host: <vm_public_ip>
      ansible_user: azureuser
      ansible_port: 22
      ansible_ssh_private_key_file: /home/<your-user>/.ssh/asterisk_vm_ed25519
      ansible_python_interpreter: /usr/bin/python3
```

Fill `livekit-sip.yml` with runtime values:

```yaml
---
livekit_fqdn: "sip.example.com"
letsencrypt_email: "ops@example.com"

livekit_api_key: "replace-with-livekit-api-key"
livekit_api_secret: "replace-with-livekit-api-secret"
ws_url: "ws://localhost:7880"
redis_address: "127.0.0.1:6379"
livekit_server_bind_address: "0.0.0.0"
livekit_server_port: 7880

sip_udp_port: 5060
sip_tls_port: 5061
rtp_udp_start: 10000
rtp_udp_end: 20000

livekit_sip_dir: "/opt/livekit-sip"
```

> **Note:** `livekit_api_key` and `livekit_api_secret` are arbitrary credentials you define yourself — they are not obtained from an external service. Choose any non-empty string pair (e.g., `APIxxxxxx` / a long random secret). These values authenticate the LiveKit SIP service against the LiveKit server, so they must match across both services. Use a strong, random secret in production.

### 3. Install Ansible dependencies

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### 4. Verify connectivity

```bash
ansible -i ansible/inventory/hosts.yml all -m ping
```

### 5. Syntax check

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/livekit-site.yml --syntax-check
```

### 6. Run playbook

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/livekit-site.yml -e @ansible/group_vars/livekit-sip.yml
```

### 7. Optional: run specific tagged roles

`livekit-site.yml` defines role tags: `livekit_common`, `livekit_cerbot`, `livekit_compose`.

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/livekit-site.yml -e @ansible/group_vars/livekit-sip.yml --tags livekit_cerbot,livekit_common
ansible-playbook -i ansible/inventory/hosts.yml ansible/livekit-site.yml -e @ansible/group_vars/livekit-sip.yml --tags livekit_compose
```