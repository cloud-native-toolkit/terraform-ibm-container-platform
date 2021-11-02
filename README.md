# IBM Cloud Cluster Module

This module interacts with a kubernetes cluster on IBM Cloud public. It can be used to create a new
cluster or to connect with an existing cluster. When creating a new cluster, the type can be set to
either `kubernetes` or `openshift`.

**Note:** This module follows the Terraform conventions regarding how provider configuration is defined within the Terraform template and passed into the module - https://www.terraform.io/docs/language/modules/develop/providers.html. The default provider configuration flows through to the module. If different configuration is required for a module, it can be explicitly passed in the `providers` block of the module - https://www.terraform.io/docs/language/modules/develop/providers.html#passing-providers-explicitly.

## Pre-requisites

This module has the following pre-requisites in order to run:

- The `IBM Cloud cli` must be installed. Information on installing the cli can be found here - https://cloud.ibm.com/docs/cli?topic=cloud-cli-getting-started
- linux shell environment

## Dependencies

- IBM Cloud Terraform provider >= 1.8.1
- Helm >= 1.1.1

## Example usage

```hcl-terraform
terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
  required_version = ">= 0.13"
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region = var.region
}

module "cluster" {
  source = "github.com/cloud-native-toolkit/terraform-ibm-container-platform.git"

  resource_group_name     = var.resource_group_name
  cluster_name            = var.cluster_name
  cluster_region          = var.region
  cluster_type            = var.cluster_type
  cluster_exists          = true
  name_prefix             = var.name_prefix
  is_vpc                  = var.vpc_cluster
}
```

