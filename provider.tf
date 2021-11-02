
provider "helm" {
  kubernetes {
    config_path = local.cluster_config
  }
}
