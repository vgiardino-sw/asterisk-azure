# Terraform - Asterisk Azure Infrastructure

This stack provisions the Azure infrastructure for the Asterisk PoC VM.

## What it creates
- Resource group
- Virtual network and subnet
- Public IP and DNS label
- NSG rules for SIP/RTP/SSH/HTTP challenge
- Ubuntu VM for Asterisk

## Prerequisites
- Terraform >= 1.6.0
- Azure credentials in your shell
- A DNS zone where you can add an A record
- A WhatsApp Business Account with SIP calling enabled
- A LiveKit instance (cloud or self-hosted)

## Setup
1. Copy backend and variable templates:
```powershell
Copy-Item env/backend.hcl.example env/backend.hcl
Copy-Item env/dev.tfvars.example env/dev.tfvars
```
2. Edit `env/dev.tfvars` with your real values.

## Required variables reference

| Variable | Description |
|----------|-------------|
| `subscription_id` | Azure subscription ID |
| `resource_group_name` | Resource group name (for example `rg-asterisk-dev`) |
| `ssh_public_keys` | List of SSH public key contents for VM access |
| `allowed_source_ips` | CIDRs allowed for SSH and SIP/RTP (usually your public IP) |
| `meta_source_ips` | Meta/WhatsApp CIDRs allowed for SIP/RTP |
| `livekit_api_source_ips` | LiveKit server CIDRs (empty for LiveKit Cloud) |
| `domain_name` | Base DNS zone (for example `example.com`) |
| `hostname` | Host label used to build `<hostname>.<domain_name>` |
| `email_for_lets_encrypt` | Email for Let's Encrypt certificate registration |
| `wa_business_phone_number` | WABA phone number, E.164 digits without `+` |
| `sip_ua_password` | Password for softphone endpoint `1001` (`direct` scenario) |
| `meta_sip_user_password` | Meta SIP password from WABA calling config |
| `livekit_auth_password` | Shared password for Asterisk <-> LiveKit trunk auth |
| `wa_consumer_phone_number` | Destination phone for B2C test calls (`direct` scenario) |
| `livekit_domain` | LiveKit SIP server FQDN |
| `poc_scenario` | `"direct"` or `"bridge"` |
| `enable_http_challenge` | `true` to open port 80 for Let's Encrypt HTTP-01 |

### How to get key values

`meta_sip_user_password`:
```bash
curl --location 'https://graph.facebook.com/v25.0/{YOUR-WABA-PHONE-NUMBER-ID}/settings?include_sip_credentials=true' \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Content-Type: application/json'
```

Generate SSH key pair (PowerShell):
```powershell
ssh-keygen -t ed25519 -C "your@email.com" -f "$HOME\.ssh\asterisk_vm_ed25519" -N ""
Get-Content "$HOME\.ssh\asterisk_vm_ed25519.pub" | Set-Clipboard
```

### Meta source IPs

Official Meta list:
https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/overview#ip-addresses

Optional helper script to collapse ranges:
```powershell
python ..\scripts\collapse_meta_cidrs.py
```

### LiveKit source IPs
- LiveKit Cloud: keep `livekit_api_source_ips = []`.
- Self-hosted LiveKit: provide your server CIDRs.

## Run
```powershell
terraform init -backend-config=env/backend.hcl
terraform fmt -check
terraform validate
terraform plan -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars
```

## After apply
- Create DNS A record: `<hostname>.<domain_name>` -> `vm_public_ip`.
- Generate Ansible handoff files from repo root:
```powershell
pwsh -File scripts/generate-ansible-inputs.ps1
```

This generates:
- `ansible/inventory/hosts.yml`
- `ansible/group_vars/vars.generated.yml`
