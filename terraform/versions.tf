#versions de Terraform et du provider Google.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Connexion à GCP : les valeurs viennent des variables.

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
