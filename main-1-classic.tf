
resource "ibm_container_cluster" "cluster" {
  count             = !var.cluster_exists && !var.is_vpc ? 1 : 0

  cluster_name_id   = local.cluster_name
  datacenter        = var.vlan_datacenter
  kube_version      = local.cluster_version
  machine_type      = var.cluster_machine_type
  hardware          = var.cluster_hardware
  default_pool_size = var.cluster_worker_count
  resource_group_id = data.ibm_resource_group.resource_group.id
  private_vlan_id   = var.private_vlan_id
  public_vlan_id    = var.public_vlan_id
  tags              = [local.cluster_type_tag]
}

data "ibm_container_cluster" "config" {
  count      = !var.is_vpc ? 1 : 0
  depends_on = [ibm_container_cluster.cluster, null_resource.create_dirs]

  name              = local.cluster_name
  alb_type          = "public"
  resource_group_id = data.ibm_resource_group.resource_group.id
}
