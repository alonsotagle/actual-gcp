variable "container_host_network_tags" {
  type        = list(string)
  description = "List of network tags to add for firewall rules"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_gcp_ed25519.pub"
}

variable "public_key" {
  type        = string
  description = "SSH public key to use if public key file doesn't exist (if running in HCP Terraform)"
  default     = ""
}

variable "user" {
  type = string
}

variable "vm_image_project" {
  type        = string
  description = "Project to which the image belongs."
}

variable "vm_size" {
  type        = string
  description = "VM instance type."
}

variable "ts_authkey" {
  type = string
}
