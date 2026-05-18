# LiveKit SIP Instance on Azure

Infrastructure and configuration for running a self-hosted LiveKit SIP instance on Azure using Terraform and Ansible.

## What this project does
- Provisions Azure network and VM resources with Terraform.
- Configures and deploys LiveKit SIP services with Ansible.
- Includes test payload examples for inbound/outbound SIP flows.

## Prerequisites
- Azure subscription and permissions to create networking + compute resources
- Terraform `>= 1.6.0`
- Ansible
- SSH key pair for VM access
- Azure authentication in your shell (`az login` or service principal env vars)

## Quickstart
1. Provision infrastructure with Terraform:
   - See [`terraform/README.md`](./terraform/README.md)
2. After Terraform apply, create your DNS A record:
   - `<hostname>.<domain_name>` -> `terraform output vm_public_ip`
3. Configure the VM and deploy LiveKit SIP with Ansible:
   - See [`ansible/README.md`](./ansible/README.md)


## Directory map
- `terraform/`: Azure infrastructure as code.
- `ansible/`: VM configuration and app deployment roles.
- `test/`: Example API payloads for SIP trunk/dispatch/participant tests.
- `outputs/`: Local debugging artifacts (ignored for publish).
- `keys/`: Local SSH materials (ignored for publish).

## Testing

### Environment setup

Export environment variables to interact with your LiveKit instance:

```powershell
$env:LIVEKIT_API_KEY = "<YOUR-LIVEKIT-API-KEY>"
$env:LIVEKIT_API_SECRET = "<YOUR-LIVEKIT-API-SECRET>"
$env:LIVEKIT_URL = "ws://<VM_PUBLIC_IP>:7880"
```

Verify connectivity:

```powershell
lk sip inbound list --json
```

> **Note:** For each test example below, replace placeholder values in the JSON files before running.

---

### Meta WhatsApp (Direct SIP)

#### Provider setup

1. Enable calling with SIP on your WhatsApp Business phone number, pointing to your LiveKit SIP instance.
2. Enable additional codecs (`PCMA`, `PCMU`).

> Replace `<YOUR-LIVEKIT-SIP-URI>` with your LiveKit SIP URI, e.g. `1a2bcdefgh.sip.livekit.cloud`.

```bash
curl --location 'https://graph.facebook.com/v25.0/<YOUR-WABA-PHONE-NUMBER-ID>/settings' \
  --header 'Authorization: Bearer <TOKEN>' \
  --header 'Content-Type: application/json' \
  --data '{
    "calling": {
      "status": "ENABLED",
      "call_icon_visibility": "DEFAULT",
      "callback_permission_status": "DISABLED",
      "sip": {
        "status": "ENABLED",
        "servers": [
          {
            "hostname": "<YOUR-LIVEKIT-SIP-URI>",
            "port": 5061
          }
        ]
      },
      "srtp_key_exchange_protocol": "SDES",
      "audio": {
        "additional_codecs": ["PCMA", "PCMU"]
      }
    }
  }'
```

> **Reference:** [Configure SIP settings on business phone number](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling/sip#configure-or-update-sip-settings-on-business-phone-number)

#### Inbound

1. Create an inbound trunk:
   ```
   lk sip inbound create livekit-instance\docs\test\meta-direct\inbound\inbound-trunk.json
   ```

2. Create a dispatch rule (use the trunk ID from step 1):
   ```
   lk sip dispatch create livekit-instance\docs\test\meta-direct\inbound\dispatch-rule.json --trunks <INBOUND-TRUNK-ID>
   ```

3. Run an [agent connected to your LiveKit instance](https://docs.livekit.io/agents/start/voice-ai/#steps).

4. Place an inbound call to the phone number configured on the trunk.

#### Outbound

1. Create an outbound trunk:
   ```
   lk sip outbound create livekit-instance\docs\test\meta-direct\outbound\outbound-trunk.json
   ```

2. Create a SIP participant (initiates the outbound call):
   ```
   lk sip participant create livekit-instance\docs\test\meta-direct\outbound\participant.json
   ```

---

### Telnyx

#### Provider setup

1. On Telnyx, create an FQDN connection using the FQDN of your provisioned LiveKit SIP instance (port `5061`).
2. Under **Inbound Settings**, set SIP transport protocol to **TLS**.

#### Inbound

1. Create an inbound trunk:
   ```
   lk sip inbound create livekit-instance\docs\test\telnyx\inbound\inbound-trunk.json
   ```

2. Create a dispatch rule (use the trunk ID from step 1):
   ```
   lk sip dispatch create livekit-instance\docs\test\telnyx\inbound\dispatch-rule.json --trunks <INBOUND-TRUNK-ID>
   ```

3. Run an [agent connected to your LiveKit instance](https://docs.livekit.io/agents/start/voice-ai/#steps).

4. Place an inbound call to the phone number configured on the trunk.

#### Outbound

1. Create an outbound trunk:
   ```
   lk sip outbound create livekit-instance\docs\test\telnyx\outbound\outbound-trunk.json
   ```

2. Create a SIP participant (initiates the outbound call):
   ```
   lk sip participant create livekit-instance\docs\test\telnyx\outbound\participant.json
   ```