# WhatsApp SIP Integration Test Findings

Date: 2026-05-07
Environment: Azure VM + Asterisk 20.6.0 + Meta WhatsApp Calling API SIP

## Summary

- Terraform/Azure provisioning: PASS
- Asterisk TLS transport bring-up: PASS after certificate readability fixes
- Meta outbound signaling (business-initiated): PASS
- Meta inbound signaling (user-initiated): PASS
- Media stability between Linphone and Asterisk: PARTIAL (SRTP auth failures on SIP UA leg)

## Findings and Resolutions

1. Terraform execution path issues
- Symptom: `No configuration files` or missing tfvars when running from repo root.
- Resolution: standardize command usage with `terraform -chdir=terraform ...`.

2. Transport object missing in PJSIP
- Symptom: `pjsip show transports` returned `No objects found`.
- Root cause: cert files were symlinked to `/etc/letsencrypt/live/...`; Asterisk user could not read effective key path.
- Resolution: copy cert/key into `/var/lib/asterisk/certs`, set owner `asterisk:asterisk`, mode `640`.
- Persisted in cloud-init: YES.

3. Invalid PJSIP auth type
- Symptom: `Unknown authentication storage type 'digest'`.
- Root cause: this Asterisk build expects `auth_type=userpass` in config, even for SIP digest protocol exchanges.
- Resolution: set `auth_type=userpass` for WhatsApp auth object.
- Persisted in cloud-init: YES.

4. Inbound call authentication failures
- Symptom: inbound Meta INVITE got challenged/rejected (`401`, failed authenticate).
- Root cause: endpoint identify template was wrongly applied to extensions 1000-1005; Meta header matching could bind to incorrect endpoint with auth.
- Resolution: remove identify blocks from 1000-1005; keep only `c2b-sip` identify with `X-FB-External-Domain: wa.meta.vc`.
- Persisted in cloud-init: YES.

5. Outbound 500 / call setup instability
- Symptom: outbound progressed to ringing but failed intermittently.
- Root cause: URI formatting and caller identity alignment.
- Resolution: enforce `+` E.164 on outbound URI and `from_user`.
- Persisted in cloud-init: YES (`sip:+${Digits}@wa.meta.vc`, `from_user=+<business_number>`).

6. IVR prompt files absent
- Symptom: `incoming_welcome` / `outgoing_welcome` missing; `Read()` collected no digits and dial target became empty.
- Resolution: upload WAV files under `/var/lib/asterisk/sounds/`; temporary testing used hardcoded `Set(Digits=...)`.
- Persisted in cloud-init: N/A (operational asset requirement).

## Current Known Gap

- `SRTP unprotect failed ... authentication failure 10` appears on the Linphone-to-Asterisk leg during bridged calls.
- Impact: call may disconnect after media starts despite successful SIP signaling and bridge establishment.
- Scope: endpoint interop issue (softphone SRTP/SDES behavior), not Terraform/Azure/Meta SIP trunk setup.

## Recommended Next Steps

1. Keep SIP signaling config as-is (now validated both directions).
2. In Linphone, constrain SRTP-SDES to `AES_CM_128_HMAC_SHA1_80` only if supported.
3. If Linphone cannot pin crypto suite reliably, test with a SIP UA that can enforce SDES cipher selection.
4. Restore normal IVR flow by using real `incoming_welcome.wav` and `outgoing_welcome.wav`.