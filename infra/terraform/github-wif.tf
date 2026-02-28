data "google_project" "current" {
  project_id = var.project_id
}

variable "github_owner" {
  description = "GitHub org/user that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without owner)"
  type        = string
}

variable "github_allowed_ref" {
  description = "Git ref allowed to impersonate the CI service account"
  type        = string
  default     = "refs/heads/main"
}

variable "github_wif_pool_id" {
  description = "Workload Identity Pool ID for GitHub Actions"
  type        = string
  default     = "github-actions-pool"
}

variable "github_wif_provider_id" {
  description = "Workload Identity Provider ID for GitHub OIDC"
  type        = string
  default     = "github-oidc"
}

variable "github_actions_service_account_id" {
  description = "Service account ID used by GitHub Actions"
  type        = string
  default     = "github-actions-cicd"
}

variable "gar_region" {
  description = "Artifact Registry region"
  type        = string
  default     = "us-central1"
}

variable "gar_repository" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "banking-services"
}

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = var.github_wif_pool_id
  display_name              = "GitHub Actions Pool"
  description               = "OIDC trust for GitHub Actions"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_wif_provider_id
  display_name                       = "GitHub OIDC Provider"
  description                        = "Trust GitHub Actions OIDC tokens"
  disabled                           = false

  attribute_mapping = {
    "google.subject"           = "assertion.sub"
    "attribute.actor"          = "assertion.actor"
    "attribute.aud"            = "assertion.aud"
    "attribute.ref"            = "assertion.ref"
    "attribute.repository"     = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.workflow_ref"   = "assertion.job_workflow_ref"
  }

  attribute_condition = "assertion.repository == '${var.github_owner}/${var.github_repo}' && assertion.ref == '${var.github_allowed_ref}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions_cicd" {
  account_id   = var.github_actions_service_account_id
  display_name = "GitHub Actions CI/CD (GAR push)"
}

# Allow the specific GitHub repo (and branch via provider condition) to impersonate the GCP SA.
resource "google_service_account_iam_member" "github_actions_workload_identity_user" {
  service_account_id = google_service_account.github_actions_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

# Least privilege for image pushes to Artifact Registry.
resource "google_artifact_registry_repository_iam_member" "github_actions_gar_writer" {
  location   = var.gar_region
  repository = var.gar_repository
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions_cicd.email}"
}

output "github_actions_wif_provider_resource_name" {
  description = "Use this value in GitHub secret GCP_WIF_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}

output "github_actions_cicd_service_account_email" {
  description = "Use this value in GitHub secret GCP_GITHUB_ACTIONS_SA_EMAIL"
  value       = google_service_account.github_actions_cicd.email
}
