variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment (dev/stage/prod)"
  type        = string
  default     = "prod"
}

variable "name_prefix" {
  description = "Prefix for GCP resource names"
  type        = string
  default     = "banking-prod"
}

variable "labels" {
  description = "Additional labels applied to resources"
  type        = map(string)
  default     = {}
}

variable "gke_subnet_cidr" {
  description = "Primary subnet CIDR for GKE nodes"
  type        = string
  default     = "10.10.0.0/20"
}

variable "gke_pods_range_name" {
  description = "Secondary range name for GKE pods"
  type        = string
  default     = "gke-pods"
}

variable "gke_pods_cidr" {
  description = "Secondary subnet CIDR for GKE pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "gke_services_range_name" {
  description = "Secondary range name for GKE services"
  type        = string
  default     = "gke-services"
}

variable "gke_services_cidr" {
  description = "Secondary subnet CIDR for GKE services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "gke_master_cidr" {
  description = "Control plane CIDR block (private cluster)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "gke_node_count" {
  description = "Initial node count for primary node pool"
  type        = number
  default     = 3
}

variable "gke_min_nodes" {
  description = "Minimum autoscaled node count"
  type        = number
  default     = 3
}

variable "gke_max_nodes" {
  description = "Maximum autoscaled node count"
  type        = number
  default     = 10
}

variable "cloudsql_database_version" {
  description = "Cloud SQL PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "cloudsql_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-4-15360"
}

variable "cloudsql_database_name" {
  description = "Core ledger database name"
  type        = string
  default     = "core_ledger"
}

variable "cloudsql_username" {
  description = "Application database username"
  type        = string
  default     = "banking_app"
}

variable "redis_memory_size_gb" {
  description = "Memorystore Redis memory size in GB"
  type        = number
  default     = 5
}

variable "redis_version" {
  description = "Memorystore Redis version"
  type        = string
  default     = "REDIS_7_0"
}
