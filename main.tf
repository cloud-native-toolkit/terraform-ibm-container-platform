provider "ibm" {
  generation = 2
  version = ">= 1.8.1"
  region = var.cluster_region
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
