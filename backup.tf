resource "google_storage_bucket" "backup" {
  name                        = "${data.google_project.project.project_id}-actual-backups"
  location                    = var.gcp_region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "container_host_backup_writer" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.container_host.email}"
}

output "backup_bucket_name" {
  description = "Google Cloud Storage bucket name for Actual Budget backups"
  value       = google_storage_bucket.backup.name
}
