module "dev_cluster" {
  source = "./module"

  resource_group_name     = var.resource_group_name
  cluster_name            = var.cluster_name
  cluster_region          = var.region
  cluster_type            = var.cluster_type
  cluster_exists          = true
  ibmcloud_api_key        = var.ibmcloud_api_key
  name_prefix             = var.name_prefix
  is_vpc                  = var.vpc_cluster
}
