output "id" {
  value       = data.ibm_container_cluster_config.cluster.id
  description = "ID of the cluster."
  depends_on  = [helm_release.ibmcloud_config]
}

output "name" {
  value       = local.cluster_name
  description = "Name of the cluster."
}

output "resource_group_name" {
  value       = var.resource_group_name
  description = "Name of the resource group containing the cluster."
  depends_on  = [helm_release.ibmcloud_config]
}

output "region" {
  value       = var.cluster_region
  description = "Region containing the cluster."
  depends_on  = [helm_release.ibmcloud_config]
}

output "ingress_hostname" {
  value       = local.ingress_hostname
  description = "(Deprecated) Ingress hostname of the cluster."
  depends_on  = [helm_release.ibmcloud_config]
}

output "server_url" {
  value       = local.server_url
  description = "The url of the control server."
  depends_on  = [helm_release.ibmcloud_config]
}

output "config_file_path" {
  value       = local.cluster_config
  description = "(Deprecated) Path to the config file for the cluster."
  depends_on  = [helm_release.ibmcloud_config]
}

output "type" {
  value       = local.cluster_type
  description = "(Deprecated, use platform.type) The type of cluster (openshift or ocp4 or ocp3 or kubernetes)"
  depends_on  = [helm_release.ibmcloud_config]
}

output "type_code" {
  value       = local.cluster_type_code
  description = "(Deprecated, use platform.type_code) The type of cluster (openshift or ocp4 or ocp3 or kubernetes)"
  depends_on  = [helm_release.ibmcloud_config]
}

output "platform" {
  value = {
    kubeconfig = local.cluster_config
    type       = local.cluster_type
    type_code  = local.cluster_type_code
    version    = local.cluster_version
    ingress    = local.ingress_hostname
    tls_secret = local.tls_secret
  }
  description = "Configuration values for the cluster platform"
  depends_on  = [helm_release.ibmcloud_config]
}

output "version" {
  value       = local.cluster_version
  description = "(Deprecated, use platform.version) The point release version number of cluster (3.11 or 4.3 or 1.16)"
  depends_on  = [helm_release.ibmcloud_config]
}

output "login_user" {
  value       = var.login_user
  description = "(Deprecated) The username used to log into the openshift cli"
  depends_on  = [helm_release.ibmcloud_config]
}

output "login_password" {
  value       = var.ibmcloud_api_key
  description = "(Deprecated) The password used to log into the openshift cli"
  depends_on  = [helm_release.ibmcloud_config]
}

output "tls_secret_name" {
  value       = local.tls_secret
  description = "(Deprecated) The name of the secret containin the tls information for the cluster"
  depends_on  = [helm_release.ibmcloud_config]
}

output "tag" {
  value       = local.cluster_type_tag
  description = "The tag based on the cluster type"
  depends_on  = [helm_release.ibmcloud_config]
}
