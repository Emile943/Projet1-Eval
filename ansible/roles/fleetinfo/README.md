# Rôle Ansible : fleetinfo

Ce rôle déploie l'application web d'information machine Fleet Info.

## Fonctionnalités
- Gestion de versions sous `/opt/fleetinfo/releases/<version>/`.
- Lien symbolique `/opt/fleetinfo/current` pointant vers la version active.
- Contrôle de santé `/health`.
- Rollback automatique en cas d'échec via un bloc `rescue`.
- Journalisation de chaque tentative dans `/var/log/fleetinfo/deploy.log`.

## Variables (`defaults/main.yml`)
| Variable | Défaut | Description |
|---|---|---|
| `fleetinfo_version` | `"1.0.0"` | Numéro de version applicative à déployer |
| `fleetinfo_simulate_failure` | `false` | Forcer une erreur pour valider le rollback |