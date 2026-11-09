data "google_compute_image" "container_optimized" {
  name    = "cos-117-18613-613-40"
  project = var.vm_image_project
}