# Asterisk on Azure - WhatsApp + LiveKit SIP PoC

This folder provisions an Azure VM running Asterisk with Terraform and configures it with Ansible.

It supports two PoC scenarios:
- `direct`: Asterisk <-> WhatsApp and Asterisk <-> LiveKit as independent paths (softphone required)
- `bridge`: Asterisk bridges WhatsApp <-> LiveKit (no softphone required)

For call flows and testing context, see:
- [`docs/poc-scenarios.md`](./docs/poc-scenarios.md)

## Prerequisites
- Terraform >= 1.6.0
- Ansible
- Azure subscription with permissions to create network and compute resources
- DNS zone where you can create an A record
- WhatsApp Business SIP calling enabled
- LiveKit instance (cloud or self-hosted)

## Setup Guides
- Terraform provisioning guide: [`terraform/README.md`](./terraform/README.md)
- Ansible configuration/deployment guide: [`ansible/README.md`](./ansible/README.md)

## High-level Flow
1. Provision infrastructure with Terraform.
2. Create/update DNS A record to point to VM public IP.
3. Generate Ansible inputs from Terraform outputs.
4. Configure the VM with Ansible.
5. Run scenario validation tests.

## Responsibility Split
- Terraform: Azure infra, NSG/ports, VM bootstrap, outputs for Ansible handoff.
- Ansible: package install, certificates, Asterisk config rendering, firewall rules, service/runtime checks.
