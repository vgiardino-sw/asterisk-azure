# Terraform - LiveKit SIP Infrastructure

This Terraform stack provisions Azure infrastructure for a LiveKit SIP host:
- Resource group
- Virtual network and subnet
- Public IP + DNS label
- Network security group and inbound rules
- Linux VM for LiveKit SIP services

## Prerequisites
- Terraform `>= 1.6.0`
- Azure credentials available in your shell (`az login` or service principal)
- An Azure subscription ID

## 1) Prepare backend config
Copy the backend example and fill your state storage values:

```bash
cp env/backend.hcl.example env/backend.hcl
```

## 2) Prepare input variables
Copy tfvars example and set your values:

```bash
cp env/dev.tfvars.example env/dev.tfvars
```

> **`ssh_public_keys`** — To generate an SSH key pair and copy the public key:
> ```powershell
> ssh-keygen -t ed25519 -C "your@email.com" -f "$HOME\.ssh\livekit_vm_ed25519" -N ""
> Get-Content "$HOME\.ssh\livekit_vm_ed25519.pub" | Set-Clipboard
> ```

Important:
- Set at least one SSH key in `ssh_public_keys`.
- Keep SSH keys as single-line OpenSSH public keys.
- Restrict `allowed_ssh_source_ips` and `allowed_livekit_api_source_ips` to trusted CIDRs.

## 3) Initialize and plan
```bash
terraform init -backend-config=env/backend.hcl
terraform fmt -check
terraform validate
terraform plan -var-file=env/dev.tfvars
```

## 4) Apply
```bash
terraform apply -var-file=env/dev.tfvars
```

## Key Variables
- `ssh_public_keys` (list(string)): One or more SSH public keys for VM admin access.
- `allowed_ssh_source_ips` (list(string)): CIDRs allowed to SSH.
- `allowed_livekit_api_source_ips` (list(string)): CIDRs allowed to hit LiveKit API port. Empty list falls back to SSH CIDRs.
- `sip_port`, `sip_tls_port`, `rtp_udp_start`, `rtp_udp_end`: SIP/media exposed ports.

## Outputs
- `vm_public_ip`
- `vm_fqdn`
- `ssh_connect_command`
- `sip_uri`

## 5). Set the DNS record

Create an A record on your DNS provider: `<hostname>.<domain_name>` → the provisioned public IP (shown in `terraform output vm_public_ip`).