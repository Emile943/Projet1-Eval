#!/usr/bin/env bash
# cloud.sh : pilote l'infrastructure Google Cloud (Terraform).
# Usage : bash scripts/cloud.sh setup | up | down
set -euo pipefail
cd "$(dirname "$0")/../terraform"

case "${1:-}" in
  setup)   # connexion Google + création de terraform.tfvars (IP détectée automatiquement)
    gcloud auth application-default login
    read -rp "Identifiant du projet Google Cloud : " PROJECT
    read -rp "Région [europe-west1] : " REGION; REGION="${REGION:-europe-west1}"
    read -rp "Zone [${REGION}-b] : " ZONE; ZONE="${ZONE:-${REGION}-b}"
    IP="$(curl -s ifconfig.me)"
    cat > terraform.tfvars <<EOF
project_id        = "${PROJECT}"
ssh_source_ranges = ["${IP}/32"]
region            = "${REGION}"
zone              = "${ZONE}"
EOF
    echo "terraform.tfvars créé (SSH autorisé depuis ${IP})."
    ;;
  up)      # crée l'infrastructure, puis vérifie qu'un second plan ne change rien
    terraform init
    terraform apply
    terraform plan
    terraform output
    ;;
  down)    # supprime toute l'infrastructure
    terraform destroy
    ;;
  *)
    echo "Usage : bash scripts/cloud.sh setup | up | down"
    exit 1
    ;;
esac