# Ansible - Asterisk VM Configuration

This folder configures the Terraform-provisioned VM and deploys Asterisk runtime settings.

## Inputs
- `inventory/hosts.yml`: target VM host/user/key (generated or manual)
- `group_vars/vars.generated.yml`: runtime values generated from Terraform
- `group_vars/all.example.yml`: optional baseline vars

## Prerequisites
- Ansible (recommended `ansible-core>=2.16,<2.18`)
- SSH access to the VM with correct private key permissions

## Setup Ansible on WSL (Ubuntu)
```bash
sudo apt update
sudo apt install -y python3-venv python3-pip
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install "ansible-core>=2.16,<2.18"
ansible --version
```

## Install collections
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

## SSH key permissions in WSL

If your key is under `C:\Users\...`, copy it into WSL and set strict permissions:
```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<your-user>/.ssh/asterisk_vm_ed25519 ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/asterisk_vm_ed25519
```

Expected inventory shape:
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

## Validate connectivity and syntax
```bash
ansible -i ansible/inventory/hosts.yml all -m ping
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --syntax-check
```

## Verify generated runtime values
Check `ansible/group_vars/vars.generated.yml` includes expected values, for example:
```yaml
poc_scenario: "direct"
livekit_domain: "azure-livekit.example.com"
livekit_auth_password: "your-real-password"
wa_consumer_phone_number: "5491155551234"
```

`livekit_auth_password` must match `authPassword` configured in LiveKit trunk resources.

## Run deployment
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml
```

Run a second time to check idempotency:
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml
```

## Post-deploy Checks

```bash
ssh azureuser@<vm_public_ip>
sudo systemctl status asterisk --no-pager
sudo asterisk -rx "core show version"
sudo asterisk -rx "pjsip show transports"
sudo asterisk -rx "pjsip show endpoints"
sudo cat /var/log/asterisk-health.log
```

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

## Optional tagged runs
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags certbot
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml -e @ansible/group_vars/vars.generated.yml --tags asterisk,ufw
```

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

## Notes
- `poc_scenario` controls direct vs bridge rendering.
- Re-running the playbook should be mostly idempotent.
- Config changes in Asterisk templates trigger service restart by design.

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

## Certificate Behavior

- `fqdn` and `letsencrypt_email` are required.
- Certbot uses **standalone** mode (requires port 80 open — set `enable_http_challenge = true`).
- Certs are copied into `/var/lib/asterisk/certs/` (`fullchain.cer` + `cer.key`).
- If issuance fails, the playbook fails.

## Common troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `UNPROTECTED PRIVATE KEY FILE` | Key copied from `/mnt/c/...` with permissive mode | Copy to `~/.ssh` and run `chmod 700 ~/.ssh && chmod 600 ~/.ssh/<key>` |
| `community.general.ufw` metadata errors | Old Ansible mixed with newer collections | Use project venv with `ansible-core>=2.16,<2.18` and reinstall collections |
| `ModuleNotFoundError: ansible.module_utils.six.moves` | Runtime/collection mismatch | Use the WSL venv setup above |
| Softphone cannot register | Wrong endpoint credentials/transport | Use user `1001`, `sip_ua_password`, TLS on `5061`, SRTP SDES |
| LiveKit 401/403 | Password mismatch | Align `livekit_auth_password` with LiveKit trunk `authPassword` |
| Cert issuance fails | Port 80 blocked or DNS mismatch | Ensure Terraform enabled HTTP challenge and DNS points to VM |
