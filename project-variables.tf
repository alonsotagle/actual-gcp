variable "gcp_project_name" {
  type        = string
  description = "Name of GCP project."
}

variable "gcp_billing_project_name" {
  type        = string
  description = "Name of GCP Billing Project."
}

variable "gcp_region" {
  type        = string
  description = "GCP region to operate in."
}

variable "gcp_zone" {
  type        = string
  description = "GCP Regional Zone to use."
}

variable "project_enabled_services" {
  type        = list(string)
  description = "List of services to enable."
}

variable "actual_password" {
  type        = string
  description = "Password for Actual Budget."
  sensitive   = true
}

variable "actual_budget_sync_id" {
  type        = string
  description = "Budget Sync ID for Actual Budget."
  sensitive   = true
}

variable "mcp_bearer_token" {
  type        = string
  description = "Bearer Token for MCP Server."
  sensitive   = true
}
