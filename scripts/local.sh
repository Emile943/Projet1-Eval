#!/usr/bin/env bash
# local.sh : pilote l'environnement local (Docker Compose + Ansible).
# Usage : bash scripts/local.sh start | up | deploy | check | down
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$SELF")/../local"

# Cle SSH presente dans le controleur ?
controller_has_key() {
  docker compose exec -T controller test -f /root/.ssh/id_ed25519 >/dev/null 2>&1
}

# Attend jusqu'a 20 s que le controleur ait recu la cle
wait_for_key() {
  local i
  for i in $(seq 1 20); do
    controller_has_key && return 0
    sleep 1
  done
  return 1
}

# Prepare tout ce qu'il faut : Docker, cle SSH, conteneurs (idempotent)
ensure_ready() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERREUR : Docker est introuvable. Installe Docker Desktop." >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERREUR : Docker ne repond pas. Demarre Docker Desktop, attends qu'il soit pret, puis relance." >&2
    exit 1
  fi
  mkdir -p ssh
  [ -f ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -C ansible-local -f ssh/id_ed25519
  docker compose up -d --build
  if ! wait_for_key; then
    echo "Cle absente du controleur : recreation des conteneurs..."
    docker compose up -d --build --force-recreate
    if ! wait_for_key; then
      echo "ERREUR : le controleur n'a pas la cle SSH (/root/.ssh/id_ed25519)." >&2
      echo "Verifie : ls local/ssh/  puis  docker compose -f local/docker-compose.yml logs controller" >&2
      exit 1
    fi
  fi
}

case "${1:-}" in
  up)      # cree la cle SSH si absente, puis demarre les 3 conteneurs
    ensure_ready
    ;;
  deploy)  # deploie l'application (le mot de passe Vault est demande)
    ensure_ready
    docker compose exec controller ansible-playbook site.yml --ask-vault-pass
    ;;
  check)   # simulation : montre ce qui changerait, sans rien modifier
    ensure_ready
    docker compose exec controller ansible-playbook site.yml --check --diff --ask-vault-pass
    ;;
  down)    # arrete et supprime les conteneurs
    docker compose down -v
    ;;
  start)   # tout d'un coup : demarrage puis deploiement
    bash "$SELF" up
    bash "$SELF" deploy
    echo "Pages : http://localhost:8081 et http://localhost:8082"
    ;;
  *)
    echo "Usage : bash scripts/local.sh start | up | deploy | check | down"
    exit 1
    ;;
esac
