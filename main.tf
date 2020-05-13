provider "ibm" {
  version = ">= 1.2.1"
}
provider "helm" {
  kubernetes {
    config_path = local.config_file_path
  }
}
provider "null" {
}
provider "local" {
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

resource "null_resource" "ibmcloud_login" {
  provisioner "local-exec" {
    command = "ibmcloud login -r $${REGION} -g $${RESOURCE_GROUP} --apikey $${APIKEY} > /dev/null"

    environment = {
      REGION         = var.cluster_region
      RESOURCE_GROUP = var.resource_group_name
      APIKEY         = var.ibmcloud_api_key
    }
  }
}

locals {
  cluster_config_dir    = "${var.kubeconfig_download_dir}/.kube"
  cluster_type_file     = "${path.cwd}/.tmp/cluster_type.val"
  cluster_version_file  = "${path.cwd}/.tmp/cluster_version.val"
  registry_url_file     = "${path.cwd}/.tmp/registry_url.val"
  registry_url          = data.local_file.registry_url.content
  name_prefix           = var.name_prefix != "" ? var.name_prefix : var.resource_group_name
  name_list             = [local.name_prefix, "cluster"]
  cluster_name          = var.cluster_name != "" ? var.cluster_name : join("-", local.name_list)
  tmp_dir               = "${path.cwd}/.tmp"
  config_namespace      = "default"
  config_file_path      = var.cluster_type == "kubernetes" ? data.ibm_container_cluster_config.cluster.config_file_path : ""
  cluster_type_tag      = var.cluster_type == "kubernetes" ? "iks" : "ocp"
  server_url            = var.is_vpc ? data.ibm_container_vpc_cluster.config[0].public_service_endpoint_url : data.ibm_container_cluster.config[0].public_service_endpoint_url
  ingress_hostname      = var.is_vpc ? data.ibm_container_vpc_cluster.config[0].ingress_hostname : data.ibm_container_cluster.config[0].ingress_hostname
  tls_secret            = var.is_vpc ? data.ibm_container_vpc_cluster.config[0].ingress_secret : data.ibm_container_cluster.config[0].ingress_secret
  openshift_versions    = {
  for version in data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions:
  substr(version, 0, 1) => "${version}_openshift"
  }
  # value should be openshift or kubernetes
  cluster_type          = var.cluster_type == "ocp3" ? "openshift" : (var.cluster_type == "ocp4" ? "openshift" : var.cluster_type)
  # value should be ocp4, ocp3, or kubernetes
  cluster_type_code     = var.cluster_type == "openshift" ? "ocp3" : var.cluster_type
  cluster_version       = local.cluster_type_code == "ocp4" ? local.openshift_versions["4"] : (local.cluster_type_code == "ocp3" ? local.openshift_versions["3"] : "")
  ibmcloud_release_name = "ibmcloud-config"
}

data "ibm_container_cluster_versions" "cluster_versions" {
  resource_group_id = data.ibm_resource_group.resource_group.id
}

resource "ibm_container_cluster" "create_cluster" {
  count             = var.cluster_exists == "true" ? 0 : 1

  name              = local.cluster_name
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
  count      = var.is_vpc ? 0 : 1
  depends_on = [ibm_container_cluster.create_cluster]

  cluster_name_id   = local.cluster_name
  alb_type          = "public"
  resource_group_id = data.ibm_resource_group.resource_group.id
}

data "ibm_container_vpc_cluster" "config" {
  count      = var.is_vpc ? 1 : 0
  depends_on = [ibm_container_cluster.create_cluster]

  cluster_name_id   = local.cluster_name
  alb_type          = "public"
  resource_group_id = data.ibm_resource_group.resource_group.id
}

resource "null_resource" "create_cluster_config_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.cluster_config_dir}"
  }
}

data "ibm_container_cluster_config" "cluster" {
  depends_on        = [
    ibm_container_cluster.create_cluster,
    null_resource.ibmcloud_login,
    null_resource.create_cluster_config_dir
  ]

  cluster_name_id   = local.cluster_name
  resource_group_id = data.ibm_resource_group.resource_group.id
  config_dir        = local.cluster_config_dir
}

resource "null_resource" "get_cluster_version" {
  depends_on = [
    data.ibm_container_cluster_config.cluster,
    null_resource.ibmcloud_login,
  ]

  provisioner "local-exec" {
    command = "ibmcloud ks cluster get --cluster $${CLUSTER_NAME} | grep \"Version\" | sed -E \"s/Version: +(.*)$/\\1/g ; s/^([0-9]+\\.[0-9]+).*/\\1/g\" | xargs echo -n > $${FILE}"

    environment = {
      CLUSTER_NAME = local.cluster_name
      FILE         = local.cluster_version_file
    }
  }
}

data "local_file" "cluster_version" {
  depends_on = [null_resource.get_cluster_version]

  filename = local.cluster_version_file
}

resource "null_resource" "oc_login" {
  count      = var.cluster_type != "kubernetes" ? 1: 0

  provisioner "local-exec" {
    command = "oc login -u ${var.login_user} -p ${var.ibmcloud_api_key} --server=${local.server_url} > /dev/null"
  }
}

# this should probably be moved to a separate module that operates at a namespace level
resource "null_resource" "create_registry_namespace" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-registry-namespace.sh ${var.resource_group_name} ${var.cluster_region} ${local.registry_url_file}"

    environment = {
      APIKEY = var.ibmcloud_api_key
    }
  }
}

data "local_file" "registry_url" {
  depends_on = [null_resource.create_registry_namespace]

  filename = local.registry_url_file
}

resource "null_resource" "setup_kube_config" {
  count = var.cluster_type == "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "rm -f ${local.cluster_config_dir}/config && ln -s ${data.ibm_container_cluster_config.cluster.config_file_path} ${local.cluster_config_dir}/config"
  }

  provisioner "local-exec" {
    command = "cp ${regex("(.*)/config.yml", data.ibm_container_cluster_config.cluster.config_file_path)[0]}/* ${local.cluster_config_dir}"
  }
}

resource "null_resource" "create_cluster_pull_secret_iks" {
  depends_on = [null_resource.setup_kube_config]
  count      = var.cluster_type == "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/cluster-pull-secret-apply.sh ${local.cluster_name}"
  }
}

resource "null_resource" "delete_ibmcloud_chart" {
  depends_on = [null_resource.oc_login, null_resource.setup_kube_config]

  provisioner "local-exec" {
    command = "${path.module}/scripts/helm3-uninstall.sh ${local.ibmcloud_release_name} ${local.config_namespace}"
  }
}

data "helm_repository" "toolkit-charts" {
  name = "toolkit-charts"
  url  = "https://ibm-garage-cloud.github.io/toolkit-charts"
}

resource "helm_release" "ibmcloud_config" {
  depends_on = [null_resource.delete_ibmcloud_chart]

  name         = local.ibmcloud_release_name
  chart        = "ibmcloud"
  repository   = data.helm_repository.toolkit-charts.name
  version      = "0.1.3"
  namespace    = local.config_namespace

  set_sensitive {
    name  = "apikey"
    value = var.ibmcloud_api_key
  }

  set {
    name  = "resource_group"
    value = var.resource_group_name
  }

  set {
    name  = "server_url"
    value = local.server_url
  }

  set {
    name  = "cluster_type"
    value = local.cluster_type
  }

  set {
    name  = "cluster_name"
    value = var.cluster_name
  }

  set {
    name  = "tls_secret_name"
    value = local.tls_secret
  }

  set {
    name  = "ingress_subdomain"
    value = local.ingress_hostname
  }

  set {
    name  = "region"
    value = var.cluster_region
  }

  set {
    name  = "registry_url"
    value = local.registry_url
  }

  set {
    name  = "cluster_version"
    value = local.cluster_version
  }
}

