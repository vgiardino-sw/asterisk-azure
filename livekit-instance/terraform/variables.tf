variable "subscription_id" {
  description = "Azure subscription ID where resources will be created."
  type        = string
}

variable "environment" {
  description = "Environment label used in tags and naming conventions."
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Resource group name for the LiveKit SIP environment."
  type        = string
}

variable "location" {
  description = "Azure region for deployment."
  type        = string
  default     = "East US"
}

variable "vm_name" {
  description = "Name of the Linux virtual machine."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_keys" {
  description = "SSH public keys allowed for VM access."
  type        = list(string)
  sensitive   = true

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "ssh_public_keys must include at least one public key."
  }
}

variable "allowed_ssh_source_ips" {
  description = "List of source CIDRs allowed to reach SSH (port 22)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_source_ips) > 0
    error_message = "allowed_ssh_source_ips must include at least one CIDR."
  }
}

variable "vnet_cidr" {
  description = "Virtual network CIDR block."
  type        = string
  default     = "10.60.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block."
  type        = string
  default     = "10.60.1.0/24"
}

variable "public_ip_name" {
  description = "Name of the public IP resource."
  type        = string
}

variable "public_ip_dns_label" {
  description = "DNS label used for Azure-managed public FQDN."
  type        = string
}

variable "sip_port" {
  description = "SIP signaling UDP port exposed to the internet."
  type        = number
  default     = 5060
}

variable "sip_tls_port" {
  description = "SIP signaling TLS port exposed to the internet."
  type        = number
  default     = 5061
}

variable "enable_http_challenge" {
  description = "Enable inbound HTTP/80 for Let's Encrypt HTTP-01 challenge."
  type        = bool
  default     = true
}

variable "livekit_api_port" {
  description = "LiveKit server API/Twirp HTTP port."
  type        = number
  default     = 7880
}

variable "allowed_livekit_api_source_ips" {
  description = "List of source CIDRs allowed to reach LiveKit API port. Empty means fallback to allowed_ssh_source_ips."
  type        = list(string)
  default     = []
}

variable "rtp_udp_start" {
  description = "Start of RTP UDP media port range exposed to the internet."
  type        = number
  default     = 10000
}

variable "rtp_udp_end" {
  description = "End of RTP UDP media port range exposed to the internet."
  type        = number
  default     = 20000

  validation {
    condition     = var.rtp_udp_start < var.rtp_udp_end
    error_message = "rtp_udp_start must be less than rtp_udp_end."
  }
}
