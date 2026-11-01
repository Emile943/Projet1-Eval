#!/usr/bin/env bash
# cloud.sh : pilote l'infrastructure Google Cloud (Terraform).
# Usage : bash scripts/cloud.sh setup | up | down
set -euo pipefail
cd "$(dirname "$0")/../terraform"

# deploy : déploie l'application sur les VM du cloud, depuis le conteneur controller.
# Arguments supplémentaires transmis à ansible-playbook (ex. --check --diff).
deploy() {
  export MSYS_NO_PATHCONV=1
  local ROOT PROJECT ADC KEY ADC_H KEY_H
  local -a DC
  ROOT="$(git rev-parse --show-toplevel)"
  cd "$ROOT"
  DC=(docker compose -f local/docker-compose.yml)

  PROJECT="$(grep '^project_id' terraform/terraform.tfvars | cut -d'"' -f2)"
  [ -n "$PROJECT" ] || { echo "project_id introuvable : lance d'abord bash scripts/cloud.sh setup"; return 1; }

  if [ -n "${APPDATA:-}" ]; then
    ADC="$APPDATA/gcloud/application_default_credentials.json"
  else
    ADC="$HOME/.config/gcloud/application_default_credentials.json"
  fi
  KEY="$HOME/.ssh/id_ed25519"
  [ -f "$ADC" ] || { echo "Identifiants Google introuvables : lance gcloud auth application-default login"; return 1; }
  [ -f "$KEY" ] || { echo "Cle SSH introuvable : $KEY"; return 1; }
  ADC_H="$(cygpath -w "$ADC" 2>/dev/null || echo "$ADC")"
  KEY_H="$(cygpath -w "$KEY" 2>/dev/null || echo "$KEY")"

  # Copie de l'inventaire avec le vrai identifiant de projet (fichier ignoré par Git)
  sed "s|{{ lookup('env', 'GCP_PROJECT') }}|$PROJECT|" ansible/inventories/cloud/fleet.gcp.yml > ansible/inventories/cloud/run.gcp.yml

  "${DC[@]}" up -d --build controller
  "${DC[@]}" exec -T controller mkdir -p /root/.config/gcloud /root/.ssh
  "${DC[@]}" cp "$ADC_H" controller:/root/.config/gcloud/application_default_credentials.json
  "${DC[@]}" cp "$KEY_H" controller:/root/.ssh/id_ed25519_cloud
  "${DC[@]}" exec -T controller chmod 600 /root/.ssh/id_ed25519_cloud
  "${DC[@]}" exec -T controller pip install -q google-auth requests

  "${DC[@]}" exec controller ansible-inventory -i inventories/cloud/run.gcp.yml --graph
  "${DC[@]}" exec -e ANSIBLE_HOST_KEY_CHECKING=False controller ansible-playbook \
    -i inventories/cloud/run.gcp.yml site.yml \
    -e ansible_ssh_private_key_file=/root/.ssh/id_ed25519_cloud \
    --ask-vault-pass "$@"
}

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
  deploy)  # déploie l'application (conteneur Ansible + inventaire dynamique)
    shift
    deploy "$@"
    ;;
  *)
    echo "Usage : bash scripts/cloud.sh setup | up | down"
    exit 1
    ;;
esac