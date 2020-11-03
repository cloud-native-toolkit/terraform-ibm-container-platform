data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

resource "null_resource" "ibmcloud_login" {
  provisioner "local-exec" {
    command = "ibmcloud login -r ${var.cluster_region} -g ${var.resource_group_name} --apikey $${APIKEY} > /dev/null"

    environment = {
      REGION         = var.cluster_region
      RESOURCE_GROUP = var.resource_group_name
      APIKEY         = var.ibmcloud_api_key
    }
  }
}

locals {
  kubernetes_versions   = {
    "kubernetes" = "1.17.7"
    "iks"        = "1.17.7"
    "iks1.15"    = "1.15.12"
    "iks1.16"    = "1.16.11"
    "iks1.17"    = "1.17.7"
    "iks1.18"    = "1.18.4"
    "openshift"  = "3.11.219_openshift"
    "ocp3"       = "3.11.219_openshift"
    "ocp4"       = "4.3.23_openshift"
    "ocp44"      = "4.4.6_openshift"
  }
  cluster_config_dir    = "${path.cwd}/.kube"
  cluster_config        = "${local.cluster_config_dir}/config"
  cluster_type_file     = "${path.cwd}/.tmp/cluster_type.val"
  name_prefix           = var.name_prefix != "" ? var.name_prefix : var.resource_group_name
  name_list             = [local.name_prefix, "cluster"]
  cluster_name          = var.cluster_name != "" ? var.cluster_name : join("-", local.name_list)
  tmp_dir               = "${path.cwd}/.tmp"
  config_namespace      = "default"
  server_url            = var.is_vpc ? length(data.ibm_container_vpc_cluster.config) > 0 ? data.ibm_container_vpc_cluster.config[0].public_service_endpoint_url : "" : length(data.ibm_container_cluster.config) > 0 ? data.ibm_container_cluster.config[0].public_service_endpoint_url : ""
  ingress_hostname      = var.is_vpc ? length(data.ibm_container_vpc_cluster.config) > 0 ? data.ibm_container_vpc_cluster.config[0].ingress_hostname : "" : length(data.ibm_container_cluster.config) > 0 ? data.ibm_container_cluster.config[0].ingress_hostname : ""
  tls_secret            = var.is_vpc ? length(data.ibm_container_vpc_cluster.config) > 0 ? data.ibm_container_vpc_cluster.config[0].ingress_secret : "" : length(data.ibm_container_cluster.config) > 0 ? data.ibm_container_cluster.config[0].ingress_secret : ""
  openshift_versions    = {
  for version in data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions:
  substr(version, 0, 3) => "${version}_openshift"
  }
  cluster_type_cleaned  = regex("(kubernetes|iks|openshift|ocp3|ocp44|ocp4).*", var.cluster_type)[0]
  cluster_type          = local.cluster_type_cleaned == "ocp3" ? "openshift" : (local.cluster_type_cleaned == "ocp44" ? "openshift" : (local.cluster_type_cleaned == "ocp4" ? "openshift" : (local.cluster_type_cleaned == "iks" ? "kubernetes" : local.cluster_type_cleaned)))
  # value should be ocp4, ocp3, or kubernetes
  cluster_type_code     = local.cluster_type_cleaned == "openshift" ? "ocp3" : (local.cluster_type_cleaned == "ocp44" ? "ocp4" : (local.cluster_type_cleaned == "iks" ? "kubernetes" : local.cluster_type_cleaned))
  cluster_type_tag      = local.cluster_type == "kubernetes" ? "iks" : "ocp"
  cluster_version       = local.cluster_type_cleaned == "ocp45" ? local.openshift_versions["4.5"] : local.cluster_type_cleaned == "ocp44" ? local.openshift_versions["4.4"] : (local.cluster_type_code == "ocp4" ? local.openshift_versions["4.3"] : (local.cluster_type_code == "ocp3" ? local.openshift_versions["3.1"] : ""))
  ibmcloud_release_name = "ibmcloud-config"
  vpc_zone_names        = var.vpc_zone_names
}

resource "null_resource" "create_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${local.cluster_config_dir}"
  }
}

data "ibm_container_cluster_versions" "cluster_versions" {
  depends_on = [null_resource.create_dirs]

  resource_group_id = data.ibm_resource_group.resource_group.id
}
