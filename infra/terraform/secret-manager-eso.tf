variable "banking_namespace" {
  description = "Kubernetes namespace where banking workloads run"
  type        = string
  default     = "banking"
}

variable "eso_ksa_name" {
  description = "Kubernetes ServiceAccount name used by ESO SecretStore auth"
  type        = string
  default     = "banking-secrets-reader"
}

variable "postgres_secret_id" {
  description = "Secret Manager secret ID for app PostgreSQL credentials"
  type        = string
  default     = "banking-prod-postgres-app-credentials"
}

variable "postgres_app_username" {
  description = "PostgreSQL app username stored in Secret Manager"
  type        = string
  default     = "banking_app"
}

resource "google_secret_manager_secret" "postgres_app_credentials" {
  secret_id = var.postgres_secret_id

  replication {
    auto {}
  }

  labels = {
    system      = "banking"
    managed_by  = "terraform"
    environment = var.environment
  }
}

resource "google_secret_manager_secret_version" "postgres_app_credentials_v1" {
  secret = google_secret_manager_secret.postgres_app_credentials.id
  secret_data = jsonencode({
    username = var.postgres_app_username
    password = random_password.cloudsql_app_password.result
  })
}

resource "google_service_account" "eso_secret_reader" {
  account_id   = "${var.name_prefix}-eso-sm-reader"
  display_name = "ESO Secret Manager Reader (${var.environment})"
}

resource "google_secret_manager_secret_iam_member" "eso_secret_accessor" {
  secret_id = google_secret_manager_secret.postgres_app_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.eso_secret_reader.email}"
}

# Bind the GKE Kubernetes ServiceAccount (KSA) used by External Secrets to the GCP Service Account (GSA).
resource "google_service_account_iam_member" "eso_ksa_workload_identity" {
  service_account_id = google_service_account.eso_secret_reader.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.banking_namespace}/${var.eso_ksa_name}]"
}

output "eso_secret_reader_gsa_email" {
  description = "Annotate the Kubernetes ServiceAccount with this GSA email"
  value       = google_service_account.eso_secret_reader.email
}
