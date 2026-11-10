# variables.tf
variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type = string
}

variable "management_group_id" {
  type        = string
  description = "Full resource ID of the management group, e.g. /providers/Microsoft.Management/managementGroups/mg-name"
}

variable "servicenow_sp_object_id" {
  type        = string
  description = "Object ID of the ServiceNow SGC service principal"
}

variable "log_analytics_retention_days" {
  type    = number
  default = 30
}
