provider "ibm" {
  generation = 2
  version = ">= 1.8.1"
  region = var.cluster_region
  ibmcloud_api_key = var.ibmcloud_api_key
}
provider "helm" {
  version = ">= 1.1.1"

  kubernetes {
    config_path = local.cluster_config
  }
}
provider "null" {
}
provider "local" {
}

terraform {
  required_version = ">= 0.12.0"

  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">= 1.22.0"
    }
  }
}