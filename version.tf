terraform {
  required_version = ">= 0.13.0"

  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">= 1.22.0"
    }
    helm = {
      version = ">= 1.1.1"
    }
  }
}

