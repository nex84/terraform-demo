# VARIABLES
}
variable "location" {
    default = "westeurope"
}
variable "appName" {}

variable "VMCount" {
    default = 1
}


# PROVIDER
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.22.1"
//   version = ">=1.22.0"
  
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}



