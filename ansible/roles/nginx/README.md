# Rôle Ansible : nginx

Ce rôle installe Nginx et prépare l'hébergement de l'application Fleet Info.

## Actions réalisées
- Installation du paquet Nginx.
- Sécurisation de l'endpoint `/status` via HTTP Basic Auth (`.htpasswd`).
- Déploiement de la configuration virtuelle via template Jinja2.
- Rechargement sans coupure (`reload`) en cas de modification.

## Variables (`defaults/main.yml`)
| Variable | Défaut | Description |
|---|---|---|
| `nginx_listen_port` | `80` | Port d'écoute du serveur web |
| `nginx_status_user` | `"admin"` | Utilisateur autorisé sur `/status` |