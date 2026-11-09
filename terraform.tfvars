vm_size                     = "e2-micro"
vm_image_project            = "cos-cloud"
container_host_network_tags = ["allow-ssh-proxy"]
project_enabled_services = [
  "cloudbilling.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "compute.googleapis.com",
  "iam.googleapis.com",
  "networkmanagement.googleapis.com"
]