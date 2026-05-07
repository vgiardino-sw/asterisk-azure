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
  description = "Resource group name for the Asterisk test environment."
  type        = string
}

variable "location" {
  description = "Azure region for deployment."
  type        = string
  default     = "East US"
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

variable "ssh_public_key" {
  description = "SSH public key content for VM access."
  type        = string
  sensitive   = true
}

variable "allowed_source_ips" {
  description = "List of source CIDRs allowed to reach SSH (port 22)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_source_ips) > 0
    error_message = "allowed_source_ips must include at least one CIDR."
  }
}

variable "meta_source_ips" {
  description = "List of Meta source CIDRs allowed to reach SIP TLS and RTP ports."
  type        = list(string)

  validation {
    condition     = length(var.meta_source_ips) > 0
    error_message = "meta_source_ips must include at least one CIDR."
  }
}

variable "sip_tls_port" {
  description = "SIP over TLS listen port."
  type        = number
  default     = 5061
}

variable "enable_http_challenge" {
  description = "Enable inbound HTTP/80 for Let's Encrypt HTTP-01 challenge."
  type        = bool
  default     = false
}

variable "rtp_udp_start" {
  description = "Start of RTP UDP media port range."
  type        = number
  default     = 10000
}

variable "rtp_udp_end" {
  description = "End of RTP UDP media port range."
  type        = number
  default     = 20000

  validation {
    condition     = var.rtp_udp_start < var.rtp_udp_end
    error_message = "rtp_udp_start must be less than rtp_udp_end."
  }
}

variable "hostname" {
  description = "Host label used for public IP DNS label and optional FQDN composition."
  type        = string
  default     = "asterisk-sip"
}

variable "domain_name" {
  description = "Base DNS zone used to build FQDN for Let's Encrypt and SIP identity."
  type        = string
  default     = ""
}

variable "email_for_lets_encrypt" {
  description = "Email used to register Let's Encrypt account."
  type        = string
}

variable "wa_business_phone_number" {
  description = "WhatsApp Business phone number in E.164 without plus (example: 15551234567)."
  type        = string
}

variable "sip_ua_password" {
  description = "Shared SIP UA password for extensions 1000-1005."
  type        = string
  sensitive   = true
}

variable "meta_sip_user_password" {
  description = "Meta SIP user password from WhatsApp calling configuration."
  type        = string
  sensitive   = true
}

variable "vnet_cidr" {
  description = "Virtual network CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block."
  type        = string
  default     = "10.42.1.0/24"
}
