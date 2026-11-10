terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46, < 5.0"
    }
  }
}
