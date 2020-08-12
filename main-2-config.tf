locals {
  gitops_dir   = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  chart_name   = "ibmcloud-setup"
  chart_dir    = "${local.gitops_dir}/${local.chart_name}"
  global_config = {
    clusterType = local.cluster_type_code
    ingressSubdomain = local.ingress_hostname
    tlsSecretName = local.tls_secret
  }
  ibmcloud_config = {
    apikey = var.ibmcloud_api_key
    resource_group = var.resource_group_name
    server_url = local.server_url
    cluster_type = local.cluster_type
    cluster_name = var.cluster_name
    tls_secret_name = local.tls_secret
    ingress_subdomain = local.ingress_hostname
    region = var.cluster_region
    cluster_version = local.cluster_version
    registry_url = local.registry_url
    registry_namespace = local.registry_namespace
  }
  github_config = {
    name = "github"
    displayName = "GitHub"
    url = "https://github.com"
    applicationMenu = true
  }
  imageregistry_config = {
    name = "registry"
    displayName = "Image Registry"
    url = "https://cloud.ibm.com/kubernetes/registry/main/images"
    privateUrl = local.registry_url
    otherSecrets = {
      namespace = local.registry_namespace
    }
    username = "iamapikey"
    password = var.ibmcloud_api_key
    applicationMenu = true
  }
  cntk_dev_guide_config = {
    name = "cntk-dev-guide"
    displayName = "Cloud-Native Toolkit"
    url = "https://cloudnativetoolkit.dev"
  }
  first_app_config = {
    name = "first-app"
    displayName = "Deploy first app"
    url = "https://cloudnativetoolkit.dev/getting-started/deploy-app"
  }
}

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

resource "null_resource" "setup-chart" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.chart_dir} && cp -R ${path.module}/chart/${local.chart_name}/* ${local.chart_dir}"
  }
}

resource "null_resource" "delete-helm-cloud-config" {
  depends_on = [null_resource.setup_kube_config]

  provisioner "local-exec" {
    command = "kubectl delete secret -n ${local.config_namespace} -l name=${local.ibmcloud_release_name} || exit 0"

    environment = {
      KUBECONFIG = local.cluster_config
    }
  }

  provisioner "local-exec" {
    command = "kubectl delete secret -n ${local.config_namespace} -l name=cloud-setup || exit 0"

    environment = {
      KUBECONFIG = local.cluster_config
    }
  }
}

resource "local_file" "cloud-values" {
  depends_on = [null_resource.setup-chart]

  content  = yamlencode({
    global = local.global_config
    cloud-setup = {
      ibmcloud = local.ibmcloud_config
      github-config = local.github_config
      imageregistry-config = local.imageregistry_config
      cntk-dev-guide = local.cntk_dev_guide_config
      first-app = local.first_app_config
    }
  })
  filename = "${local.chart_dir}/values.yaml"
}

resource "null_resource" "print-values" {
  provisioner "local-exec" {
    command = "cat ${local_file.cloud-values.filename}"
  }
}

resource "helm_release" "cloud_setup" {
  depends_on = [null_resource.setup_kube_config, null_resource.delete-helm-cloud-config, local_file.cloud-values]

  name              = "cloud-setup"
  chart             = local.chart_dir
  version           = "0.1.0"
  namespace         = local.config_namespace
  timeout           = 1200
  dependency_update = true
  force_update      = true
  replace           = true

  disable_openapi_validation = true
}
