terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend intentionally left local by default for bootstrap simplicity.
  # Configure an azurerm backend in backend.hcl when ready for remote state.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}