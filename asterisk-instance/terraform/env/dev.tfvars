subscription_id     = "a5a86e7a-a5a4-4a0f-98b6-605001cf22b2"
environment         = "dev"
resource_group_name = "rg-asterisk-dev"
location            = "East US"
vm_size             = "Standard_B2s"
admin_username      = "azureuser"
ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1l2HzdQzLvFMgfp2uZeKRZ2eFSjQlJN0LUFOsFqMvh valentino.giardino@southworks.com",
]
allowed_source_ips = [
  "181.116.200.241/32", # My current IP
]
meta_source_ips = [
  "31.13.24.0/21",
  "31.13.64.0/18",
  "45.64.40.0/22",
  "57.141.0.0/20",
  "57.141.16.0/22",
  "57.141.20.0/23",
  "57.144.0.0/14",
  "66.220.144.0/20",
  "69.63.176.0/20",
  "69.171.224.0/19",
  "74.119.76.0/22",
  "102.132.96.0/20",
  "103.4.96.0/22",
  "129.134.0.0/16",
  "147.75.208.0/20",
  "157.240.0.0/16",
  "163.70.128.0/17",
  "163.77.128.0/17",
  "173.252.64.0/18",
  "179.60.192.0/22",
  "185.60.216.0/22",
  "185.89.216.0/22",
  "189.247.71.0/24",
  "204.15.20.0/22",
]
enable_http_challenge    = true
sip_tls_port             = 5061
rtp_udp_start            = 10000
rtp_udp_end              = 20000
hostname                 = "asterisk"
domain_name              = "vgiardino.com"
email_for_lets_encrypt   = "valentino.giardino@southworks.com"
wa_business_phone_number = "5493875168717"
sip_ua_password          = "N7v!2qL9#sP4xK8m"
meta_sip_user_password   = "04UOxePjHAHP6exOYlcyeoqeCiW6YTPb"
wa_consumer_phone_number   = "5493875761526"
livekit_auth_password      = "strongpassword"
livekit_domain             = "azure-livekit.vgiardino.com"
poc_scenario               = "direct"