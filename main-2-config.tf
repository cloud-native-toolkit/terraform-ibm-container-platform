data "ibm_container_cluster_config" "cluster" {
  depends_on        = [
    ibm_container_cluster.cluster,
    ibm_container_vpc_cluster.cluster,
    null_resource.ibmcloud_login,
  ]

  cluster_name_id   = local.cluster_name
  resource_group_id = data.ibm_resource_group.resource_group.id
  config_dir        = local.cluster_config_dir
}

# this should probably be moved to a separate module that operates at a namespace level
resource "null_resource" "create_registry_namespace" {
  depends_on = [null_resource.create_dirs, null_resource.ibmcloud_login]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-registry-namespace.sh ${local.registry_namespace} ${var.cluster_region} ${local.registry_url_file}"

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
  depends_on = [null_resource.create_dirs]

  provisioner "local-exec" {
    command = "rm -f ${local.cluster_config} && ln -s ${data.ibm_container_cluster_config.cluster.config_file_path} ${local.cluster_config}"
  }

  provisioner "local-exec" {
    command = "cp ${regex("(.*)/config.yml", data.ibm_container_cluster_config.cluster.config_file_path)[0]}/* ${local.cluster_config_dir}"
  }
}

resource "null_resource" "create_cluster_pull_secret_iks" {
  depends_on = [null_resource.setup_kube_config]
  count      = local.cluster_type == "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/cluster-pull-secret-apply.sh ${local.cluster_name}"

    environment = {
      KUBECONFIG     = local.cluster_config
    }
  }
}

resource "null_resource" "delete_ibmcloud_chart" {
  depends_on = [null_resource.setup_kube_config]

  provisioner "local-exec" {
    command = "${path.module}/scripts/helm3-uninstall.sh ${local.ibmcloud_release_name} ${local.config_namespace}"

    environment = {
      KUBECONFIG     = local.cluster_config
    }
  }
}

resource "helm_release" "ibmcloud_config" {
  depends_on = [null_resource.delete_ibmcloud_chart]

  name         = local.ibmcloud_release_name
  chart        = "ibmcloud"
  repository   = "https://ibm-garage-cloud.github.io/toolkit-charts"
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

  set {
    name  = "registry_namespace"
    value = local.registry_namespace
  }
}

