locals {
  tags = {
    project     = "livekit-sip"
    environment = var.environment
    managed_by  = "terraform"
    owner       = "tech-titans"
    costCenter  = "demo"
  }
}
