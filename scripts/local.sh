#!/usr/bin/env bash
# local.sh : pilote l'environnement local (Docker Compose + Ansible).
# Usage : bash scripts/local.sh start | up | deploy | check | down
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"  
cd "$(dirname "$SELF")/../local"

case "${1:-}" in
  up)      # crée la clé SSH si absente, puis démarre les 3 conteneurs
    mkdir -p ssh
    [ -f ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -C ansible-local -f ssh/id_ed25519
    docker compose up -d --build
    ;;
  deploy)  # déploie l'application (le mot de passe Vault est demandé)
    docker compose exec controller ansible-playbook site.yml --ask-vault-pass
    ;;
  check)   # simulation : montre ce qui changerait, sans rien modifier
    docker compose exec controller ansible-playbook site.yml --check --diff --ask-vault-pass
    ;;
  down)    # arrête et supprime les conteneurs
    docker compose down -v
    ;;
  start)   # tout d'un coup : démarrage puis déploiement
    bash "$SELF" up
    bash "$SELF" deploy
    echo "Pages : http://localhost:8081 et http://localhost:8082"
    ;;
  *)
    echo "Usage : bash scripts/local.sh start | up | deploy | check | down"
    exit 1
    ;;
esac