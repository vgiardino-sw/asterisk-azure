# Terraform Asterisk on Azure (WhatsApp SIP guide aligned)

This repo provisions an Azure VM and bootstraps Asterisk with config aligned to Meta's "Asterisk using SIP" integration example.

## Important

Run Terraform from the `terraform` directory or use `-chdir=terraform`.

## Usage

1. Create tfvars:

```powershell
Copy-Item terraform/env/dev.tfvars.example terraform/env/dev.tfvars
```

2. Edit `terraform/env/dev.tfvars` with real values:

- `subscription_id`
- `ssh_public_key`
- `allowed_source_ips`
- `meta_source_ips`
- `domain_name`
- `wa_business_phone_number` (E.164 digits, no plus)
- `sip_ua_password`
- `meta_sip_user_password`

3. Init/validate/plan/apply:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file="env/dev.tfvars"
terraform -chdir=terraform apply -var-file="env/dev.tfvars"
```

## What gets configured on the VM

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

## Certificate behavior

- If DNS + Let's Encrypt issuance succeeds, certs are copied into `/var/lib/asterisk/certs/`.
- If issuance fails, a temporary self-signed cert is generated so Asterisk still starts.

## Post-deploy checks

```powershell
ssh azureuser@<vm_public_ip>
sudo systemctl status asterisk --no-pager
sudo asterisk -rx "core show version"
sudo asterisk -rx "pjsip show transports"
sudo asterisk -rx "pjsip show endpoints"
sudo cat /var/log/asterisk-health.log
```

## Test findings

See `docs/test-findings.md` for a full troubleshooting and validation log.
