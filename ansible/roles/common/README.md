# Rôle Ansible : common

Ce rôle installe le socle de base sur les serveurs Debian 12.

## Actions réalisées
- Mise à jour du cache APT et installation des paquets de base (`curl`, `htop`, `apache2-utils`).
- Configuration du fuseau horaire du serveur.
- Déploiement de la bannière d'avertissement dans `/etc/motd`.

## Variables par défaut (`defaults/main.yml`)
| Variable | Valeur par défaut | Description |
|---|---|---|
| `common_timezone` | `"Etc/UTC"` | Fuseau horaire configuré sur la machine |
| `common_packages` | `[curl, htop, apache2-utils]` | Liste des paquets de base à installer |

## Dépendances
Aucune.