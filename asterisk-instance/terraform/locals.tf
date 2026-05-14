locals {
  tags = {
    project     = "asterisk-azure"
    environment = var.environment
    managed_by  = "terraform"
    owner       = "vgiardino"
    costCenter  = "demo"
  }

  fqdn = trimspace(var.hostname) != "" && trimspace(var.domain_name) != "" ? "${trimspace(var.hostname)}.${trimspace(var.domain_name)}" : ""

  cloud_init = templatefile("${path.module}/cloud-init/asterisk.yaml.tftpl", {})

  # NOTE: We are adding source IPs here to enable testing with local Softphones
  sip_and_media_source_ips = distinct(concat(var.allowed_source_ips, var.meta_source_ips))

  # Note: Livekit Cloud uses dynamic IPs, so we need to allow all IPs for SIP/TLS and RTP/UDP. 
  # If you are using Livekit self-hosted, you can specify the IPs of your Livekit server(s) in the livekit_api_source_ips variable and the rules will be more restrictive.
  livekit_sip_is_open    = length(var.livekit_api_source_ips) == 0
  livekit_sip_source_ips = length(var.livekit_api_source_ips) > 0 ? var.livekit_api_source_ips : null
}
