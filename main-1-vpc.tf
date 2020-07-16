
resource "ibm_is_vpc" "vpc" {
  count = !var.cluster_exists && var.is_vpc ? 1 : 0

  name = "${local.cluster_name}-vpc"
}

resource "ibm_is_public_gateway" "vpc_gateway" {
  count = !var.cluster_exists && var.is_vpc ? length(var.vpcs) : 0

  name  = "${local.cluster_name}-gateway-${format("%02s", count.index)}"
  vpc   = ibm_is_vpc.vpc[0].id
  zone  = var.vpcs[count.index].zone_name

  //User can configure timeouts
  timeouts {
    create = "90m"
  }
}

resource "ibm_is_subnet" "vpc_subnet" {
  count                    = !var.cluster_exists && var.is_vpc ? length(var.vpcs) : 0

  name                     = "${local.cluster_name}-subnet-${format("%02s", count.index)}"
  zone                     = var.vpcs[count.index].zone_name
  vpc                      = ibm_is_vpc.vpc[0].id
  public_gateway           = ibm_is_public_gateway.vpc_gateway[count.index].id
  total_ipv4_address_count = 256
  resource_group           = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_security_group_rule" "vpc_security_group_rule_tcp_k8s" {
  count     = !var.cluster_exists && var.is_vpc ? length(var.vpcs) : 0

  group     = ibm_is_vpc.vpc[0].default_security_group
  direction = "inbound"
  remote    = ibm_is_subnet.vpc_subnet[count.index].ipv4_cidr_block

  tcp {
    port_min = 30000
    port_max = 32767
  }
}

resource "ibm_resource_instance" "cos_instance" {
  count    = !var.cluster_exists && local.cluster_type_code == "ocp4" && var.is_vpc ? 1 : 0

  name     = "${local.cluster_name}-ocp_cos_instance"
  service  = "cloud-object-storage"
  plan     = "standard"
  location = "global"
}

resource "ibm_container_vpc_cluster" "cluster" {
  count             = !var.cluster_exists && var.is_vpc ? 1 : 0

  name              = local.cluster_name
  vpc_id            = ibm_is_vpc.vpc[0].id
  flavor            = var.vpcs[0].flavor
  worker_count      = var.vpcs[0].worker_count
  kube_version      = local.cluster_version
  entitlement       = "cloud_pak"
  cos_instance_crn  = local.cluster_type_code == "ocp4" ? ibm_resource_instance.cos_instance[0].id : ""
  resource_group_id = data.ibm_resource_group.resource_group.id
  wait_till         = "IngressReady"

  zones {
    name      = var.vpcs[0].zone_name
    subnet_id = ibm_is_subnet.vpc_subnet[0].id
  }
}

resource "ibm_container_vpc_worker_pool" "cluster_pool" {
  count             = !var.cluster_exists && var.is_vpc ? length(var.vpcs) - 1 : 0

  cluster           = ibm_container_vpc_cluster.cluster[0].id
  worker_pool_name  = "${local.cluster_name}-wp-${format("%02s", count.index + 1)}"
  flavor            = var.vpcs[count.index + 1].flavor
  vpc_id            = ibm_is_vpc.vpc[0].id
  worker_count      = var.vpcs[count.index + 1].worker_count
  resource_group_id = data.ibm_resource_group.resource_group.id

  zones {
    name      = var.vpcs[count.index + 1].zone_name
    subnet_id = ibm_is_subnet.vpc_subnet[count.index + 1].id
  }
}

data "ibm_container_vpc_cluster" "config" {
  count      = var.is_vpc ? 1 : 0
  depends_on = [ibm_container_vpc_cluster.cluster, null_resource.create_dirs]

  cluster_name_id   = local.cluster_name
  alb_type          = "public"
  resource_group_id = data.ibm_resource_group.resource_group.id
}
