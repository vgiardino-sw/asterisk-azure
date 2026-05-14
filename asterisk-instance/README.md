# Terraform Asterisk on Azure (WhatsApp SIP guide aligned)

This repo provisions an Azure VM with Terraform and configures Asterisk with Ansible, aligned to Meta's "Asterisk using SIP" integration example.

## Important

Run Terraform from the `terraform` directory.

## Setup and Run

### 1. Prepare Terraform vars

```powershell
Copy-Item terraform/env/dev.tfvars.example terraform/env/dev.tfvars
```

Edit `terraform/env/dev.tfvars` with real values:

- `subscription_id`
- `ssh_public_key`
- `allowed_source_ips`
- `meta_source_ips`
- `domain_name`
- `wa_business_phone_number` (E.164 digits, no plus)
- `sip_ua_password`
- `meta_sip_user_password`

To generate and ssh key run this command:

ssh-keygen -t ed25519 -C "your@email.com" -f "$HOME\.ssh\asterisk_vm_ed25519" -N ""

copy the ssh key:

Get-Content "$HOME\.ssh\asterisk_vm_ed25519.pub" | Set-Clipboard


---
For allowing Meta IPs, you can find the list of ips they use:

https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview#ip-addresses

This repo provide an script to collapse them 
scripts\collapse_meta_cidrs.py

### 2. Provision infrastructure with Terraform

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

### 3. Set the DNS record on your DNS management platform
Create an A record with the value of the specified hostname pointing to the provisioned external ip

### 3. Generate Ansible inventory and runtime vars from Terraform outputs

```powershell
pwsh -File scripts/generate-ansible-inputs.ps1
```

### 4. Install Ansible on WSL (Ubuntu)

Run these commands in WSL:

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install "ansible-core>=2.16,<2.18"
ansible --version
```

Install required Ansible collections:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### 5. Ensure SSH key permissions in WSL

If your key is stored on `C:\Users\...`, copy it into WSL and fix permissions:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<your-user>/.ssh/asterisk_vm_ed25519 ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/asterisk_vm_ed25519
```

Use the key in [`ansible/inventory/hosts.yml`](/C:/Users/ValentinoGiardino/Documents/southworks/repositories/asterisk-azure/ansible/inventory/hosts.yml):

```yaml
all:
  hosts:
    asterisk_vm:
      ansible_host: 20.124.130.98
      ansible_user: azureuser
      ansible_port: 22
      ansible_ssh_private_key_file: /home/<your-user>/.ssh/asterisk_vm_ed25519
      ansible_connection: ssh
      ansible_python_interpreter: /usr/bin/python3
```

Quick connectivity test:

```bash
ansible -i ansible/inventory/hosts.yml all -m ping
```

### 6. Run Ansible configuration

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml
```

Run a second time to verify idempotency (expect mostly `ok` and close to zero `changed`):

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml
```

Runtime behavior:
- When `extensions.conf`, `pjsip.conf`, or `rtp.conf` changes, Ansible triggers a full `asterisk` restart via handler.
- This is intentional to avoid stale PJSIP/TLS runtime state after config updates.

### 7. Optional: run specific tagged roles

`site.yml` defines role tags:
- `common`
- `certbot`
- `asterisk`
- `ufw`

Examples:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags certbot
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags asterisk,ufw
```

## Responsibility split

- Terraform:
  - Azure infra (networking, NSG, VM)
  - minimal cloud-init bootstrap for Ansible prerequisites
  - outputs required for Ansible handoff
- Ansible:
  - package installation (`asterisk`, `certbot`, `ufw`, utilities)
  - certificate provisioning via Let's Encrypt
  - rendering Asterisk configs
  - firewall rules and Asterisk service/health checks

## What gets configured on the VM by Ansible

- `/etc/asterisk/extensions.conf` with:
  - `c2b-sub-dial` IVR flow
  - `whatsapp` context extensions `10XX`
  - `b2c-sip` flow dialing `sip:+${Digits}@wa.meta.vc`
  - incoming route `_+<wa-business-phone-number>`
  - no dependency on local `.wav` prompt files
- `/etc/asterisk/pjsip.conf` with:
  - TLS transport on `5061`
  - cert paths `/var/lib/asterisk/certs/fullchain.cer` and `/var/lib/asterisk/certs/cer.key`
  - SDES endpoint templates and extensions `1000-1005`
  - `rewrite_contact=no`
  - dedicated `c2b-sip` identify by `X-FB-External-Domain: wa.meta.vc`
  - WhatsApp endpoint/auth blocks (`auth_type=userpass`, `from_user=+<business_number>`)
- `/etc/asterisk/rtp.conf` with STUN and RTP range `10000-20000`

## Certificate behavior (Ansible)

- `fqdn` and `letsencrypt_email` are required.
- Let's Encrypt certs are issued/copied into `/var/lib/asterisk/certs/`.
- If issuance fails, playbook execution fails.

## Post-deploy checks

```powershell
ssh azureuser@<vm_public_ip>
sudo systemctl status asterisk --no-pager
sudo asterisk -rx "core show version"
sudo asterisk -rx "pjsip show transports"
sudo asterisk -rx "pjsip show endpoints"
sudo cat /var/log/asterisk-health.log
```

## Troubleshooting flow

- Infra issues (`terraform plan/apply`, NSG, VM provisioning): debug Terraform first.
- Runtime issues (Asterisk config, certs, service, UFW): debug Ansible playbook and host state.

## Troubleshooting details

- `UNPROTECTED PRIVATE KEY FILE`:
  - Cause: key from `/mnt/c/...` has permissive permissions in WSL.
  - Fix: copy key into `~/.ssh` and run `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/<key>`.
- `community.general.ufw` plugin metadata errors:
  - Cause: old system Ansible (for example `2.10.x`) mixed with newer collections.
  - Fix: use project venv with modern `ansible-core` (`>=2.16,<2.18`) and reinstall collections.
- `ModuleNotFoundError: ansible.module_utils.six.moves`:
  - Cause: incompatible Ansible runtime and collection/module versions.
  - Fix: use the WSL venv flow above instead of distro Ansible.

