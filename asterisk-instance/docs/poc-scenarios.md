# PoC Scenarios

This Asterisk instance supports two independent Proof-of-Concept scenarios, controlled by the `poc_scenario` variable.

---

## Prerequisites

### WhatsApp Business

- WhatsApp Business Account (WABA) with calling enabled and SIP configuration pointing to this Asterisk instance's FQDN.

```bash
curl --location 'https://graph.facebook.com/v25.0/{YOUR-WABA-PHONE-NUMBER-ID}/settings' \
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
  }
```

- On the destination phone, add the WABA phone number as a contact and enable calls for that contact.

### LiveKit

A LiveKit instance is required (cloud or self-hosted). Configure the following resources using the [LiveKit CLI](https://docs.livekit.io/home/cli/lk/):

**1. Inbound trunk** (handles calls from Asterisk → LiveKit):

```bash
lk sip trunk create-inbound docs/demo-configs/livekit/inbound/asterisk-inbound-trunk.json
```

> Set `authPassword` to match the `livekit_auth_password` Ansible variable (rendered into `pjsip-<direct|bridge>.conf.j2`):
> ```ini
> [livekit-auth]
> type=auth
> auth_type=userpass
> username=asterisk
> password=<livekit_auth_password>
> ```

**2. Dispatch rule** (assigns an agent to the incoming room):

```bash
lk sip dispatch-rule create docs/demo-configs/livekit/inbound/asterisk-dispatch-rule.json
```

> Replace the `trunkIds` value with the trunk ID returned by step 1.

**3. Outbound trunk** (handles calls from LiveKit → Asterisk):

```bash
lk sip trunk create-outbound docs/demo-configs/livekit/outbound/asterisk-outbound-trunk.json
```

> Set `authPassword` to match the same `livekit_auth_password` value.

### LiveKit Agent (recommended)

For testing inbound calls to LiveKit, have an agent running that can handle incoming calls (so it gets added to the SIP call room via the dispatch rule).

---

## PoC 1: "direct" — Independent WhatsApp + LiveKit

Asterisk connects independently to both Meta WhatsApp SIP Gateway and a LiveKit SIP server. Each path is tested separately.

### Call Flows

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  B2C-SIP: Asterisk → WhatsApp                                              │
│                                                                             │
│  Softphone ──► Asterisk (ext b2c-sip) ──► Meta SIP Gateway ──► WhatsApp    │
│                                                                             │
│  Dialplan: [whatsapp] context, extension "b2c-sip"                          │
│  PJSIP endpoints: 1001 (softphone), whatsapp (trunk)                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  C2B: WhatsApp → Asterisk                                                   │
│                                                                             │
│  WhatsApp User ──► Meta SIP Gateway ──► Asterisk (c2b-sip) ──► Softphone   │
│                                                                             │
│  Dialplan: [whatsapp] context, matches +<wa_business_phone_number>          │
│            Goto(c2b-sub-dial,s,1) → Dial(PJSIP/1001)                        │
│  PJSIP endpoints: c2b-sip (identify via X-FB-External-Domain), 1001        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  Asterisk → LiveKit                                                         │
│                                                                             │
│  Softphone ──► Asterisk (ext 7000) ──► LiveKit SIP Server                   │
│                                                                             │
│  Dialplan: [whatsapp] context, extension "7000"                             │
│  PJSIP endpoints: 1001 (softphone), livekit (trunk)                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  LiveKit → Asterisk                                                         │
│                                                                             │
│  LiveKit SIP Server ──► Asterisk (ext 7001) ──► Softphone                   │
│                                                                             │
│  Dialplan: [from-livekit] context, extension "7001"                         │
│  PJSIP endpoints: livekit (identify via X-LiveKit-Trunk), 1001             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### PJSIP Endpoints Loaded

| Endpoint    | Purpose                       |
|-------------|-------------------------------|
| `1001`      | SIP UA / Softphone (Linphone) |
| `c2b-sip`   | Meta inbound identify (C2B)   |
| `b2c-sip`   | Meta outbound (B2C)           |
| `whatsapp`  | Meta SIP Gateway trunk        |
| `livekit`   | LiveKit SIP trunk             |

### Templates Used

- `extensions-direct.conf.j2` → `/etc/asterisk/extensions.conf`
- `pjsip-direct.conf.j2` → `/etc/asterisk/pjsip.conf`

### Softphone Setup (Linphone)

1. Download [Linphone](https://www.linphone.org/getting-started).
2. Add a new **third-party SIP account** with:
   - **Username:** `1001`
   - **Password:** `<sip_ua_password>`
   - **Domain:** `<fqdn>`
   - **Transport:** TLS
3. Under **Advanced Parameters:**
   - Enable all audio codecs.
   - Set media encryption to **SRTP**.
   - Toggle on **mandatory media encryption**.

Reference: [Meta — Configuring a VoIP phone](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling/integration-examples#configuring-a-voip-phone)

### Testing PoC 1

| Test | Steps | Expected Result |
|------|-------|-----------------|
| **B2C-SIP** (Asterisk → WhatsApp) | From Linphone, call `b2c-sip` | The destination phone receives a call from the WABA number |
| **C2B** (WhatsApp → Asterisk) | From the destination phone, call the WABA number via WhatsApp | Linphone rings |
| **Asterisk → LiveKit** | From Linphone, call `7000` | LiveKit receives the call and dispatches to a room (with agent if configured) |
| **LiveKit → Asterisk** | Update `trunkId` in `docs/demo-configs/livekit/outbound/asterisk-participant.json`, then run: `lk sip participant create docs/demo-configs/livekit/outbound/asterisk-participant.json` | Linphone rings |

---

## PoC 2: "bridge" — WhatsApp ↔ LiveKit via Asterisk

Asterisk acts as a bridge between Meta WhatsApp SIP Gateway and LiveKit. No softphone is involved.

### Call Flows

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  WhatsApp → LiveKit (C2B bridged)                                           │
│                                                                             │
│  WhatsApp User ──► Meta SIP GW ──► Asterisk (c2b-sip) ──► LiveKit          │
│                                                                             │
│  Dialplan: [whatsapp] context, matches +<wa_business_phone_number>          │
│            Dial(PJSIP/7000@livekit,30)                                      │
│  PJSIP endpoints: c2b-sip (identify), livekit (trunk)                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  LiveKit → WhatsApp (B2C bridged)                                           │
│                                                                             │
│  LiveKit Agent ──► Asterisk (from-livekit) ──► Meta SIP GW ──► WhatsApp     │
│                                                                             │
│  Dialplan: [from-livekit] context, matches +X. pattern                      │
│            Dial(PJSIP/${EXTEN}@whatsapp,60)                                 │
│  PJSIP endpoints: livekit (identify), whatsapp (trunk)                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### PJSIP Endpoints Loaded

| Endpoint    | Purpose                     |
|-------------|-----------------------------|
| `c2b-sip`   | Meta inbound identify (C2B) |
| `whatsapp`  | Meta SIP Gateway trunk      |
| `livekit`   | LiveKit SIP trunk           |

**Not loaded:** `1001` (no softphone), `b2c-sip` (no direct outbound test)

### Templates Used

- `extensions-bridge.conf.j2` → `/etc/asterisk/extensions.conf`
- `pjsip-bridge.conf.j2` → `/etc/asterisk/pjsip.conf`

### Testing PoC 2

| Test | Steps | Expected Result |
|------|-------|-----------------|
| **WhatsApp → LiveKit** | From the destination phone, call the WABA number via WhatsApp | LiveKit receives the call and dispatches to a room (with agent if configured) |
| **LiveKit → WhatsApp** | Update `trunkId` and `sip_call_to` in `docs/demo-configs/livekit/outbound/whatsapp-participant.json`, then run: `lk sip participant create docs/demo-configs/livekit/outbound/whatsapp-participant.json` | The destination WhatsApp phone number rings |

---

## Switching Between PoCs

### 1. Set the variable

In `ansible/group_vars/vars.generated.yml` (or your vars file), change:

```yaml
# For PoC 1 (direct WhatsApp + LiveKit):
poc_scenario: "direct"

# For PoC 2 (WhatsApp ↔ LiveKit bridge):
poc_scenario: "bridge"
```

### 2. Re-run the playbook

```bash
ansible-playbook site.yml --tags asterisk
```

Or override inline without editing the file:

```bash
ansible-playbook site.yml --tags asterisk -e poc_scenario=direct
ansible-playbook site.yml --tags asterisk -e poc_scenario=bridge
```

### 3. Verify

```bash
sudo asterisk -rx "pjsip show endpoints"
sudo asterisk -rx "dialplan show"
```

---

## Variable Reference

| Variable                   | Description                              | Example                       |
|----------------------------|------------------------------------------|-------------------------------|
| `poc_scenario`             | Active PoC: `"direct"` or `"bridge"`     | `"bridge"`                    |
| `sip_tls_port`             | TLS SIP listening port                   | `5061`                        |
| `external_ip`              | Public IP of the Asterisk VM             | `20.124.1.120`                |
| `local_net`                | Local subnet (for NAT traversal)         | `10.42.1.0/24`                |
| `domain_name`              | Domain for SIP From header               | `example.com`                 |
| `wa_business_phone_number` | WhatsApp Business phone number (no `+`)  | `5493875168717`               |
| `sip_ua_password`          | Password for SIP UA endpoints (1001)     | —                             |
| `meta_sip_user_password`   | Meta SIP Gateway authentication password | —                             |
| `livekit_domain`           | LiveKit SIP server FQDN                  | `azure-livekit.example.com`   |
| `livekit_auth_password`    | Asterisk ↔ LiveKit SIP trunk auth password (shared by inbound/outbound) | —     |
| `wa_consumer_phone_number` | Destination phone number for B2C test calls (E.164, no `+`) | `5493875761526` |

---

## File Structure

```
roles/asterisk/templates/
├── extensions-direct.conf.j2    # PoC 1 dialplan
├── extensions-bridge.conf.j2    # PoC 2 dialplan
├── pjsip-direct.conf.j2        # PoC 1 PJSIP (all endpoints)
├── pjsip-bridge.conf.j2        # PoC 2 PJSIP (bridge-only endpoints)
└── rtp.conf.j2                  # RTP config (shared by both PoCs)
```
