# Asterisk on Azure — WhatsApp + LiveKit SIP PoC

This folder provisions an Azure VM running Asterisk via **Terraform** and configures it with **Ansible**. It supports two PoC scenarios: a "direct" mode where a softphone interacts independently with WhatsApp and LiveKit, and a "bridge" mode where Asterisk bridges WhatsApp ↔ LiveKit without a softphone.

## PoC Scenarios

| Scenario | Description | Softphone needed? |
|----------|-------------|:-:|
| `direct` | Asterisk ↔ WhatsApp + Asterisk ↔ LiveKit (independent paths) | Yes (`1001`) |
| `bridge` | Asterisk bridges WhatsApp ↔ LiveKit | No |

See [docs/poc-scenarios.md](docs/poc-scenarios.md) for call flow diagrams, prerequisites, and testing instructions.

## Prerequisites

- **Terraform** ≥ 1.6.0
- A **DNS zone** where you can add an A record
- A **WhatsApp Business Account** with SIP calling enabled. See: [Configure SIP settings on business phone number](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling/sip#configure-or-update-sip-settings-on-business-phone-number).
- A **LiveKit** instance (cloud or self-hosted) with CLI (`lk`) installed

---

## Setup and Run

### 1. Prepare Terraform vars

```powershell
Copy-Item terraform/env/dev.tfvars.example terraform/env/dev.tfvars
```

Edit `terraform/env/dev.tfvars` with real values:

| Variable | Description |
|----------|-------------|
| `subscription_id` | Azure subscription ID |
| `resource_group_name` | Resource group name (e.g. `rg-asterisk-dev`) |
| `ssh_public_keys` | List of SSH public key contents for VM access |
| `allowed_source_ips` | CIDRs allowed for SSH and SIP/RTP (your IP) |
| `meta_source_ips` | Meta/WhatsApp CIDRs for SIP/RTP |
| `livekit_api_source_ips` | LiveKit server CIDRs (leave empty for LiveKit Cloud — opens to all) |
| `domain_name` | Base DNS zone (e.g. `example.com`) |
| `hostname` | Host label (combined as `<hostname>.<domain_name>` for FQDN) |
| `email_for_lets_encrypt` | Email for Let's Encrypt certificate registration |
| `wa_business_phone_number` | WABA phone number, E.164 digits without `+` |
| `sip_ua_password` | Password for softphone endpoint `1001` (PoC "direct" only) |
| `meta_sip_user_password` | Meta SIP password from WABA calling config |
| `livekit_auth_password` | Shared password for Asterisk ↔ LiveKit trunk auth |
| `wa_consumer_phone_number` | Destination phone for B2C test calls, E.164 without `+` |
| `livekit_domain` | LiveKit SIP server FQDN |
| `poc_scenario` | `"direct"` or `"bridge"` |
| `enable_http_challenge` | `true` to open port 80 for Let's Encrypt HTTP-01 |

> **`meta_sip_user_password`** — The SIP password provided by Meta when you enable SIP calling on your WABA phone number.
> You can retrieve it with:
> ```bash
> curl --location 'https://graph.facebook.com/v25.0/{YOUR-WABA-PHONE-NUMBER-ID}/settings?include_sip_credentials=true' \
>   --header 'Authorization: Bearer <TOKEN>' \
>   --header 'Content-Type: application/json'
> ```

> **`livekit_auth_password`** — A password you choose. Used for mutual authentication between Asterisk and the LiveKit SIP trunk (both inbound and outbound trunks share the same credentials). Must match the `authPassword` in your LiveKit trunk resources.

> **`sip_ua_password`** — A password you choose. Used by the SIP UA softphone (e.g. Linphone) to register as endpoint `1001` on Asterisk. Only needed for PoC "direct".

> **`ssh_public_keys`** — To generate an SSH key pair and copy the public key:
> ```powershell
> ssh-keygen -t ed25519 -C "your@email.com" -f "$HOME\.ssh\asterisk_vm_ed25519" -N ""
> Get-Content "$HOME\.ssh\asterisk_vm_ed25519.pub" | Set-Clipboard
> ```

#### Meta source IPs

For allowing Meta IPs, see the official list:
https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview#ip-addresses

This repo provides a script to collapse them into CIDR ranges:

```powershell
python scripts/collapse_meta_cidrs.py
```

#### LiveKit source IPs

- **LiveKit Cloud**: leave `livekit_api_source_ips = []` — the NSG will allow SIP/RTP from any source for the LiveKit rules (LiveKit Cloud uses dynamic IPs).
- **Self-hosted LiveKit**: populate `livekit_api_source_ips` with your server CIDRs for tighter rules.

### 2. Provision infrastructure with Terraform

```powershell
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

### 3. Set the DNS record

Create an A record on your DNS provider: `<hostname>.<domain_name>` → the provisioned public IP (shown in `terraform output vm_public_ip`).

### 4. Generate Ansible inputs from Terraform outputs

```powershell
pwsh -File scripts/generate-ansible-inputs.ps1
```

This generates:
- `ansible/inventory/hosts.yml` — Ansible inventory with VM connection details
- `ansible/group_vars/vars.generated.yml` — Runtime variables from Terraform state

### 5. Install Ansible on WSL (Ubuntu)

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

### 6. Ensure SSH key permissions in WSL

If your key is stored on `C:\Users\...`, copy it into WSL and fix permissions:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<your-user>/.ssh/asterisk_vm_ed25519 ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/asterisk_vm_ed25519
```

Update `ansible/inventory/hosts.yml` with the correct key path:

```yaml
all:
  hosts:
    asterisk_vm:
      ansible_host: <vm_public_ip>
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

### 7. Verify generated variables

Open `ansible/group_vars/vars.generated.yml` and confirm all values are populated:

```yaml
poc_scenario: "direct"                    # or "bridge"
livekit_domain: "azure-livekit.example.com"
livekit_auth_password: "your-real-password"  # must match LiveKit trunk authPassword
wa_consumer_phone_number: "5491155551234"    # only needed for PoC "direct"
```

> **Important:** `livekit_auth_password` must match the `authPassword` configured on your LiveKit inbound and outbound trunks. If Terraform defaults it to `"strongpassword"`, update `dev.tfvars` and re-run steps 2 and 4.

### 8. Run Ansible configuration

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

### 9. Optional: run specific tagged roles

`site.yml` defines role tags: `common`, `certbot`, `asterisk`, `ufw`.

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags certbot
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags asterisk,ufw
```

---

## Switching Between PoCs

1. Change `poc_scenario` in `terraform/env/dev.tfvars` and re-run Terraform + generate script, **or** edit `ansible/group_vars/vars.generated.yml` directly.
2. Re-run the playbook (at minimum the `asterisk` tag):

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags asterisk
```

Or override inline:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml -e poc_scenario=bridge
```

3. Verify:

```bash
sudo asterisk -rx "pjsip show endpoints"
sudo asterisk -rx "dialplan show"
```

## Responsibility Split

| Layer     | Responsibilities |
|-----------|------------------|
| Terraform | Azure infra (RG, VNet, NSG, public IP, VM with Ubuntu 24.04), cloud-init bootstrap, Terraform outputs for Ansible handoff |
| Ansible   | Package installation (`asterisk`, `certbot`, `ufw`, utilities), Let's Encrypt certificates, Asterisk config rendering (PJSIP + dialplan + RTP), firewall rules, service management and health checks |

## What Gets Configured on the VM

The Ansible `asterisk` role renders three configuration files based on the active `poc_scenario`:

### Shared (both scenarios)

- `/etc/asterisk/rtp.conf` — STUN server and RTP port range (`10000`–`20000`)
- `/etc/asterisk/pjsip.conf` — TLS transport on port `5061`, cert paths at `/var/lib/asterisk/certs/`
- `/etc/asterisk/extensions.conf` — Dialplan (scenario-specific, see below)

### PoC "direct" — Asterisk ↔ WhatsApp + Asterisk ↔ LiveKit

**PJSIP** (`pjsip-direct.conf.j2`):
- SDES endpoint template + auth/aor templates
- SIP UA endpoint `1001` for softphone registration (password: `sip_ua_password`)
- `c2b-sip` identify (inbound Meta, matched by `X-FB-External-Domain: wa.meta.vc`)
- `b2c-sip` endpoint (outbound Meta)
- `whatsapp` trunk (endpoint + auth + aor targeting `wa.meta.vc`)
- `livekit` trunk (endpoint + auth + aor + identify via `X-LiveKit-Trunk`)

**Dialplan** (`extensions-direct.conf.j2`):
- `[whatsapp]` context: `b2c-sip` → dials `wa_consumer_phone_number` via Meta, `_10XX` range, `7000` → LiveKit, `+<wa_business_phone_number>` → C2B sub-dial
- `[c2b-sub-dial]` context: routes inbound Meta calls to softphone `1001`
- `[from-livekit]` context: `7001` → softphone `1001`

### PoC "bridge" — WhatsApp ↔ LiveKit

**PJSIP** (`pjsip-bridge.conf.j2`):
- SDES endpoint template + aor template
- `c2b-sip` identify (inbound Meta)
- `whatsapp` trunk (same as direct)
- `livekit` trunk (same as direct, context `from-livekit`)
- **Not included:** `1001`, `b2c-sip`, `authtemplate` (no softphone needed)

**Dialplan** (`extensions-bridge.conf.j2`):
- `[whatsapp]` context: `+<wa_business_phone_number>` → `PJSIP/7000@livekit`
- `[from-livekit]` context: `+X.` pattern → `PJSIP/${EXTEN}@whatsapp`

## Certificate Behavior (Ansible)

- `fqdn` and `letsencrypt_email` are required.
- Certbot uses **standalone** mode (requires port 80 open — set `enable_http_challenge = true`).
- Certs are copied into `/var/lib/asterisk/certs/` (`fullchain.cer` + `cer.key`).
- If issuance fails, the playbook fails.

## Post-deploy Checks

```bash
ssh azureuser@<vm_public_ip>
sudo systemctl status asterisk --no-pager
sudo asterisk -rx "core show version"
sudo asterisk -rx "pjsip show transports"
sudo asterisk -rx "pjsip show endpoints"
sudo cat /var/log/asterisk-health.log
```

## Troubleshooting

**Infra issues** (`terraform plan/apply`, NSG, VM provisioning): debug Terraform first.
**Runtime issues** (Asterisk config, certs, service, UFW): debug Ansible playbook and host state.

| Error | Cause | Fix |
|-------|-------|-----|
| `UNPROTECTED PRIVATE KEY FILE` | Key from `/mnt/c/...` has permissive permissions in WSL | Copy key into `~/.ssh` and run `chmod 700 ~/.ssh && chmod 600 ~/.ssh/<key>` |
| `community.general.ufw` plugin metadata errors | Old system Ansible (e.g. `2.10.x`) mixed with newer collections | Use project venv with `ansible-core>=2.16,<2.18` and reinstall collections |
| `ModuleNotFoundError: ansible.module_utils.six.moves` | Incompatible Ansible runtime and collection versions | Use the WSL venv flow (step 5) instead of distro Ansible |
| Softphone can't register | Wrong credentials or transport settings | Username: `1001`, Password: `sip_ua_password`, TLS on port 5061, SRTP (SDES) mandatory |
| LiveKit calls fail with 401/403 | `livekit_auth_password` mismatch | Ensure Ansible var matches `authPassword` in LiveKit trunk JSON configs |
| Cert issuance fails | Port 80 not open or DNS not pointing to VM | Set `enable_http_challenge = true` in tfvars and verify DNS A record |

### Debugging

SSH into the VM and connect to the Asterisk CLI:

```bash
sudo asterisk -vvvvvr
```

Enable relevant loggers from the Asterisk console:

```
pjsip set logger on       ; SIP signaling (INVITE, 200 OK, BYE, etc.)
core set verbose 5         ; dialplan execution trace
core set debug 5           ; internal debug messages
rtp set debug on           ; RTP media stream debugging (optional)
```
