terraform {
  required_version = ">= 0.13.0"

  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">= 1.22.0"
    }
  }
}

provider "ibm" {
  region           = var.region
  generation       = 2
  ibmcloud_api_key = var.ibmcloud_api_key
}