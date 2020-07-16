# Resource Group Variables
variable "resource_group_name" {
  type        = string
  description = "The name of the IBM Cloud resource group where the cluster will be created/can be found."
}

# Cluster Variables
variable "cluster_name" {
  type        = string
  description = "The name of the cluster that will be created within the resource group"
}

# Cluster Variables
variable "cluster_hardware" {
  type        = string
  description = "The type of hardware for the cluster (shared, dedicated)"
  default     = "shared"
}

# Cluster Variables
variable "cluster_worker_count" {
  type        = number
  description = "(Deprecated, use VPC) The number of worker nodes that should be provisioned for classic infrastructure"
  default     = 3
}

variable "cluster_machine_type" {
  type        = string
  description = "(Deprecated, use VPC) The machine type that will be provisioned for classic infrastructure"
  default     = "b3c.4x16"
}

variable "vlan_datacenter" {
  type        = string
  description = "(Deprecated, use VPC) The datacenter that should be used for classic infrastructure provisioning"
  default     = ""
}

variable "private_vlan_id" {
  type        = string
  description = "(Deprecated, use VPC) The private vlan id that should be used for classic infrastructure provisioning"
  default     = ""
}

variable "public_vlan_id" {
  type        = string
  description = "(Deprecated, use VPC) The public vlan id that should be used for classic infrastructure provisioning"
  default     = ""
}

# VPC Variables
variable "vpcs" {
  type        = list(object({
    zone_name = string
    worker_count = number
    flavor = string
  }))
  default = []
}

variable "cluster_region" {
  type        = string
  description = "The IBM Cloud region where the cluster will be/has been installed."
}

variable "cluster_type" {
  type        = string
  description = "The type of cluster that should be created (openshift or ocp3 or ocp4 or kubernetes)"
}

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud api token"
}

variable "cluster_exists" {
  type        = bool
  description = "Flag indicating if the cluster already exists (true or false)"
}

variable "login_user" {
  type        = string
  description = "The username to log in to openshift"
  default     = "apikey"
}

variable "name_prefix" {
  type        = string
  description = "The prefix name for the service. If not provided it will default to the resource group name"
  default     = ""
}

variable "is_vpc" {
  type        = bool
  description = "Flag indicating that the cluster uses vpc infrastructure"
  default     = false
}

variable "registry_namespace" {
  type        = string
  description = "The namespace that will be created in the IBM Cloud image registry. If not provided the value will default to the resource group"
  default     = ""
}
