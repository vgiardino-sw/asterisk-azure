resource "azurerm_network_security_group" "this" {
  name                = "${var.resource_group_name}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "sip_tls" {
  name                        = "allow-sip-tls"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.sip_tls_port)
  source_address_prefixes     = local.sip_and_media_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "rtp_udp" {
  name                        = "allow-rtp-udp"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_ranges     = ["${var.rtp_udp_start}-${var.rtp_udp_end}"]
  source_address_prefixes     = local.sip_and_media_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "rtp_udp_livekit" {
  name                        = "allow-rtp-udp-livekit"
  priority                    = 115
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_ranges     = ["${var.rtp_udp_start}-${var.rtp_udp_end}"]
  source_address_prefix       = local.livekit_sip_is_open ? "*" : null
  source_address_prefixes     = local.livekit_sip_is_open ? null : local.livekit_sip_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "sip_livekit_tls" {
  name                        = "allow-sip-tls-livekit"
  priority                    = 111
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5061"]
  source_address_prefix       = local.livekit_sip_is_open ? "*" : null
  source_address_prefixes     = local.livekit_sip_is_open ? null : local.livekit_sip_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "http_challenge" {
  count                       = var.enable_http_challenge ? 1 : 0
  name                        = "allow-http-challenge"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}
