# Socle Web Automatisé : Terraform + Ansible sur Google Cloud

Dernière mise à jour : 4 novembre 2026

Ce dépôt déploie, en quelques commandes, l'infrastructure et l'application **Fleet Info** (une page web d'information sur le serveur qui la sert), sur Google Cloud et en local, de façon reproductible et idempotente.

**Terraform crée l'infrastructure, Ansible la configure et y déploie l'application** : les deux outils ne se recouvrent jamais.

## Sommaire

1. [Présentation](#1-présentation)
2. [Architecture et structure du dépôt](#2-architecture-et-structure-du-dépôt)
3. [Prérequis et accès](#3-prérequis-et-accès)
4. [Déploiement de zéro](#4-déploiement-de-zéro)
5. [Runbooks d'exploitation](#5-runbooks-dexploitation)
6. [Référence des variables](#6-référence-des-variables)
7. [Décisions techniques](#7-décisions-techniques)
8. [Où regarder en cas de problème](#8-où-regarder-en-cas-de-problème)
9. [Limites connues et dette technique](#9-limites-connues-et-dette-technique)

## 1. Présentation

| | Automatisé | Non automatisé |
| --- | --- | --- |
| Cloud | VPC, sous-réseau, pare-feu, 2 VM Debian 12 (Terraform) ; nginx et Fleet Info (Ansible) | Création du projet GCP (lab), `gcloud auth`, choix de la zone |
| Local | 2 nœuds Debian + contrôleur Ansible (Docker Compose) | Génération de la clé SSH locale (faite par `scripts/local.sh`) |
| Application | Releases versionnées, bascule par lien symbolique, retour arrière automatique | Choix du numéro de version à déployer |
| Secrets | Chiffrement avec Ansible Vault | Transmission du mot de passe Vault entre membres |

## 2. Architecture et structure du dépôt

Terraform construit le réseau et les VM sur GCP, Docker Compose reproduit des VM en local, et un même `site.yml` Ansible configure les deux : seuls l'inventaire et les `group_vars` changent.

```
                     Dépôt Git : terraform/  ansible/  local/  scripts/
                          |                        |
        ENVIRONNEMENT CLOUD                        |        ENVIRONNEMENT LOCAL
  +-----------------------------------+            |   +-----------------------------------+
  | Terraform -> VPC + sous-réseau    |            |   | docker compose up                 |
  |              pare-feu (tag réseau)|            |   |   controller (Ansible)            |
  |              2 VM Debian 12       |            |   |   node1, node2 (Debian, systemd)  |
  |              (labels + tag)       |            |   |                                   |
  | Ansible -> inventaire dynamique   |            |   | Ansible -> inventaire statique    |
  |            google.cloud.gcp_compute            |   |            (groupe web)           |
  +----------------+------------------+            |   +----------------+------------------+
                   |                               |                    |
                   +------------ MÊME site.yml, MÊMES rôles, MÊMES templates ------------+
```

### Ressources Terraform

| Module | Ressource | Rôle |
| --- | --- | --- |
| `modules/network` | `google_compute_network.vpc` | VPC dédié en mode custom |
| `modules/network` | `google_compute_subnetwork.subnet` | Sous-réseau des VM |
| `modules/network` | `google_compute_firewall.allow_http` | TCP 80 depuis Internet, vers les VM portant le tag réseau |
| `modules/network` | `google_compute_firewall.allow_ssh` | TCP 22 depuis `ssh_source_ranges` seulement, vers les mêmes VM |
| `modules/compute` | `google_compute_instance.vm` (x `vm_count`) | VM Debian 12 avec labels `env`, `role`, `team`, tag réseau et clé SSH publique |

**Frontière Terraform / Ansible.** Terraform ne touche jamais au contenu des machines et Ansible ne crée aucune VM. Le lien entre les deux est la paire labels + tag réseau, que l'inventaire dynamique lit pour classer les VM dans le groupe `web`.

### Structure du dépôt

**Infrastructure cloud, dossier `terraform/`**

| Fichier | Rôle |
| --- | --- |
| `versions.tf` | Versions de Terraform et du fournisseur Google |
| `variables.tf` | Réglages : projet, région, zone, nombre de VM, type de machine |
| `main.tf` | Assemble les modules réseau puis VM |
| `outputs.tf` | Affiche IP, noms des VM, du VPC et du sous-réseau |
| `terraform.tfvars.example` | Modèle des valeurs à remplir |
| `terraform.tfvars` | Valeurs réelles du lab (non versionné) |
| `modules/network/` | VPC, sous-réseau, pare-feu HTTP et SSH |
| `modules/compute/` | VM Debian 12 avec labels, tag réseau et clé SSH |

**Environnement local, dossier `local/`**

| Fichier | Rôle |
| --- | --- |
| `docker-compose.yml` | Démarre les 2 nœuds et le contrôleur Ansible |
| `node/Dockerfile` | Nœud : Debian 12 avec systemd, SSH, Python, sudo |
| `controller/Dockerfile` | Contrôleur avec Ansible et ses collections |
| `controller/entrypoint.sh` | Installe la clé SSH dans le contrôleur au démarrage |
| `ssh/` | Clés SSH locales générées (non versionné) |

**Connexion d'Ansible aux machines, dossier `ansible/inventories/`**

| Fichier | Rôle |
| --- | --- |
| `local/hosts.yml` | Liste fixe des nœuds locaux, groupe `web` |
| `local/group_vars/all.yml` | Utilisateur et clé SSH en local |
| `cloud/fleet.gcp.yml` | Retrouve les VM de Google par leurs labels |
| `cloud/group_vars/all.yml` | Utilisateur et clé SSH en cloud |
| `cloud/run.gcp.yml` | Copie du précédent avec le vrai projet (non versionné, générée) |

**Configuration des serveurs et application, dossier `ansible/`**

| Fichier | Rôle |
| --- | --- |
| `site.yml` | Point d'entrée, appelle les trois rôles |
| `ansible.cfg` | Réglages d'Ansible |
| `roles/common/` | Socle commun : paquets, fuseau horaire |
| `roles/nginx/` | Serveur web et page `/status` protégée |
| `roles/fleetinfo/` | Application versionnée, contrôle `/health`, retour arrière, journal |
| `group_vars/all/vars.yml`, `vault.yml` | Variables et secrets chiffrés |

**Scripts, dossier `scripts/`**

| Fichier | Rôle |
| --- | --- |
| `local.sh` | `start`, `up`, `deploy`, `check`, `down` pour le local |
| `cloud.sh` | `setup`, `up`, `deploy`, `down` pour le cloud |

## 3. Prérequis et accès

| Outil | Version testée | Rôle |
| --- | --- | --- |
| Terraform | 1.16.6 (minimum 1.5) | Crée l'infrastructure GCP |
| Google Cloud SDK (`gcloud`) | | Authentification de Terraform et de l'inventaire dynamique |
| Docker Desktop + Compose | 29.8.0 | Environnement local et poste de contrôle Ansible |
| Git, VS Code | | Dépôt et édition |

Ansible n'est pas installé sur le poste : il tourne dans le conteneur `controller`, car il ne fonctionne pas nativement sous Windows. Les commandes de ce document sont celles de Git Bash sous Windows.

**Comptes et droits.** Un projet GCP temporaire fourni par le lab Google Skills (identifiants et `project_id` différents à chaque session) et un accès en écriture au dépôt GitHub.

**Mot de passe Vault.** Il est transmis par le responsable Ansible et n'est jamais écrit dans le dépôt. Il se saisit à chaque lancement (`--ask-vault-pass`).

**Contraintes observées dans le lab (session du 1er novembre 2026)**

- Durée d'environ 1 heure : le projet et tout son contenu sont supprimés à la fin.
- Région imposée : `europe-west1` est refusée (erreur 412, contrainte `gcp.resourceLocations`), `us-west1` / `us-west1-b` est acceptée. À vérifier à chaque session.
- OS Login est activé sur le projet : les VM le désactivent explicitement, sans quoi les clés SSH des métadonnées sont ignorées.
- Ne pas utiliser Cloud Shell : le travail serait perdu à la fin du lab.

## 4. Déploiement de zéro

Le même `site.yml` sert dans les deux environnements. Toutes les commandes se lancent depuis la racine du dépôt.

```bash
git clone https://github.com/Emile943/Projet1-Eval.git
cd Projet1-Eval
```

### Local (Docker Compose)

Version rapide : une commande crée la clé SSH, démarre les conteneurs, demande le mot de passe Vault et déploie l'application.

```bash
bash scripts/local.sh start
```

Versions détaillées, pas à pas :

1. Générer la clé SSH locale, ignorée par Git :

   ```bash
   mkdir -p local/ssh
   ssh-keygen -t ed25519 -N "" -C ansible-local -f local/ssh/id_ed25519
   ```

2. Démarrer les trois conteneurs : `cd local && docker compose up -d --build`. Attendu : `node1`, `node2` et `controller` à l'état `Running`.
3. Tester la connexion : `docker compose exec controller ansible web -m ping --ask-vault-pass`. Attendu : `SUCCESS` et `"ping": "pong"` pour chaque nœud.
4. Déployer : `docker compose exec controller ansible-playbook site.yml --ask-vault-pass`. Attendu : `failed=0` et `unreachable=0`, puis les pages sur `http://localhost:8081` et `http://localhost:8082`.
5. Arrêter : `bash scripts/local.sh down` (supprime conteneurs et données).

### Cloud (projet de lab)

Raccourci pour les étapes 2 à 5 : `bash scripts/cloud.sh setup` puis `bash scripts/cloud.sh up`. Raccourci pour les étapes 6 à 8 : `bash scripts/cloud.sh deploy`, validé de bout en bout sur un lab réel (second passage à `changed=0`).

1. S'authentifier : `gcloud auth application-default login`, avec le compte du lab, dans une fenêtre privée. Laisser le terminal ouvert jusqu'à `Credentials saved`.
2. Préparer les valeurs : `cd terraform && cp terraform.tfvars.example terraform.tfvars`, puis renseigner `project_id`, `ssh_source_ranges` (son IP en `/32`, via `curl -s ifconfig.me`) et `region` / `zone` si le lab les impose.
3. `terraform init`, puis `terraform plan`. Attendu : `Plan: 6 to add`.
4. `terraform apply` (répondre `yes`). Attendu : `Apply complete! Resources: 6 added` et les IP des VM.
5. `terraform plan` à nouveau. Attendu : `No changes. Your infrastructure matches the configuration.`
6. Préparer le poste de contrôle Ansible : démarrer le conteneur `controller`, y copier les identifiants Google et la clé SSH, et générer `run.gcp.yml` (commandes ci-dessous, à lancer depuis la racine du dépôt).
7. Vérifier l'inventaire dynamique. Attendu : les VM dans le groupe `web`.
8. Déployer avec `ansible-playbook`. Attendu : `failed=0` pour chaque VM ; un second passage doit afficher `changed=0`.

```bash
export MSYS_NO_PATHCONV=1
PROJECT=$(grep '^project_id' terraform/terraform.tfvars | cut -d'"' -f2)
DC="docker compose -f local/docker-compose.yml"
sed "s|{{ lookup('env', 'GCP_PROJECT') }}|$PROJECT|" ansible/inventories/cloud/fleet.gcp.yml > ansible/inventories/cloud/run.gcp.yml
$DC up -d --build controller
$DC exec -T controller mkdir -p /root/.config/gcloud /root/.ssh
$DC cp "$(cygpath -w "$APPDATA/gcloud/application_default_credentials.json")" controller:/root/.config/gcloud/application_default_credentials.json
$DC cp "$(cygpath -w ~/.ssh/id_ed25519)" controller:/root/.ssh/id_ed25519_cloud
$DC exec -T controller chmod 600 /root/.ssh/id_ed25519_cloud
$DC exec -T controller pip install -q google-auth requests
$DC exec controller ansible-inventory -i inventories/cloud/run.gcp.yml --graph
$DC exec -e ANSIBLE_HOST_KEY_CHECKING=False controller ansible-playbook -i inventories/cloud/run.gcp.yml site.yml -e ansible_ssh_private_key_file=/root/.ssh/id_ed25519_cloud --ask-vault-pass
```

Ces commandes sont celles de Git Bash sous Windows ; sous Linux ou macOS, remplacer `$APPDATA/gcloud` par `~/.config/gcloud` et supprimer `cygpath -w`. Ne pas laisser `export MSYS_NO_PATHCONV=1` actif dans un terminal où l'on utilise ensuite `gcloud` : il casse ses chemins (`unset MSYS_NO_PATHCONV` ou nouveau terminal).

Le fichier `run.gcp.yml` est une copie de l'inventaire avec le vrai identifiant du projet : le plugin Google n'évalue pas lui-même la variable d'environnement, et l'identifiant ne doit pas être dans un fichier versionné. Il est ignoré par Git et à régénérer à chaque lab.

Pour détruire : `bash scripts/cloud.sh down`. À chaque nouveau lab, supprimer d'abord l'ancien state (`rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup`), qui décrit un projet disparu.

## 5. Runbooks d'exploitation

Sept opérations courantes. En local, les commandes Ansible se lancent depuis `local/` avec le préfixe `docker compose exec controller`.

| Opération | Quand | Commandes | Vérification |
| --- | --- | --- | --- |
| Déployer une nouvelle version | Livraison d'une release | Changer `fleetinfo_version` dans `ansible/group_vars/all/vars.yml`, ou ajouter `-e fleetinfo_version=1.1.0` ; puis `bash scripts/cloud.sh deploy` (cloud) ou `docker compose exec controller ansible-playbook site.yml --ask-vault-pass` (local) | La page et `/health` affichent la nouvelle version |
| Tester le retour arrière | Démonstration, ou valider le mécanisme | Ajouter `-e fleetinfo_simulate_failure=true` à la commande de déploiement | Le retour à la version précédente se déclenche, le site reste en ligne, la tentative est tracée dans `/var/log/fleetinfo/deploy.log` |
| Retour arrière manuel | Release défectueuse déjà active | Sur le serveur : `sudo ln -sfn /opt/fleetinfo/releases/<ancienne> /opt/fleetinfo/current` | `/health` renvoie l'ancienne version |
| Ajouter ou retirer un serveur | Changement de capacité | Cloud : modifier `vm_count` dans `terraform.tfvars`, `terraform apply`, relancer le déploiement. Local : ajouter un service dans `docker-compose.yml` et l'hôte dans `inventories/local/hosts.yml` | `ansible-inventory --graph` liste la machine dans `web` |
| Modifier la configuration nginx | Changement de configuration | Modifier le modèle du rôle `nginx`, puis relancer le déploiement | `nginx -t` valide, la page reste servie |
| Changer les mots de passe | Rotation | `/status` : `ansible-vault edit group_vars/all/vault.yml`. Mot de passe Vault : `ansible-vault rekey group_vars/all/vault.yml` | `/status` refuse l'ancien mot de passe |
| Vérifier la conformité | Audit sans modification | `bash scripts/cloud.sh deploy --check --diff` (cloud) ou `bash scripts/local.sh check` (local) | `changed=0` si le serveur est conforme |
| Détruire proprement | Fin de session | Cloud : `bash scripts/cloud.sh down`. Local : `bash scripts/local.sh down` | `Destroy complete! Resources: 6 destroyed` |

## 6. Référence des variables

Toutes les valeurs propres à une session de lab se renseignent dans `terraform/terraform.tfvars` (copie de `terraform.tfvars.example`, ignorée par Git). Aucune variable n'est sensible : la clé SSH est publique, seul son chemin est fourni.

### Terraform (`terraform/variables.tf`)

| Nom | Description | Type | Défaut |
| --- | --- | --- | --- |
| `project_id` | ID du projet GCP du lab | `string` | **obligatoire** |
| `ssh_source_ranges` | IP autorisées en SSH (jamais `0.0.0.0/0`) | `list(string)` | **obligatoire** |
| `region` | Région GCP | `string` | `europe-west1` |
| `zone` | Zone GCP | `string` | `europe-west1-b` |
| `vm_count` | Nombre de VM | `number` | `2` |
| `machine_type` | Type de machine | `string` | `e2-small` |
| `network_name` | Nom du VPC | `string` | `fleet-vpc` |
| `subnet_name` | Nom du sous-réseau | `string` | `fleet-subnet` |
| `subnet_cidr` | Plage d'IP du sous-réseau | `string` | `10.10.0.0/24` |
| `network_tag` | Tag réseau commun aux VM | `string` | `fleet-web` |
| `vm_name_prefix` | Préfixe du nom des VM | `string` | `fleet-web` |
| `labels` | Labels des VM | `map(string)` | `env=cloud`, `role=web`, `team=plateforme` |
| `ssh_user` | Utilisateur Linux créé sur les VM | `string` | `ansible` |
| `ssh_public_key_path` | Chemin de la clé SSH publique | `string` | `~/.ssh/id_ed25519.pub` |

Les valeurs par défaut de `region` et `zone` sont refusées par le lab observé : les renseigner dans `terraform.tfvars` (`us-west1`, `us-west1-b`).

**Fournisseurs.** Terraform `>= 1.5.0` ; `hashicorp/google` en `~> 6.0`, déclarés uniquement dans `terraform/versions.tf`.

### Sorties Terraform (`terraform output`)

| Sortie | Contenu |
| --- | --- |
| `network_name` | Nom du VPC |
| `subnet_name` | Nom du sous-réseau |
| `vm_names` | Noms des VM |
| `vm_public_ips` | IP publique de chaque VM (nom vers IP) |

### Ansible et environnement local

| Variable | Où | Rôle |
| --- | --- | --- |
| `fleetinfo_version` | `ansible/group_vars/all/vars.yml` | Version de l'application à déployer |
| `fleetinfo_simulate_failure` | `roles/fleetinfo/defaults/main.yml` (défaut `false`) | Provoque un échec de déploiement pour tester le retour arrière |
| `common_timezone` | `roles/common/defaults/main.yml` | Fuseau horaire (`Etc/UTC`) |
| `ansible_user`, `ansible_ssh_private_key_file` | `inventories/<env>/group_vars/all.yml` | Connexion SSH, propre à chaque environnement |
| `ANSIBLE_CONFIG` | `local/docker-compose.yml` | Chemin explicite de `ansible.cfg` dans le contrôleur |
| `projects` (dans `run.gcp.yml`) | Fichier non versionné, généré | Identifiant du projet du lab, écrit par la commande `sed` dans la copie de l'inventaire dynamique |

Les variables de `vars.yml` et `vault.yml` sont à compléter par le responsable Ansible.

## 7. Décisions techniques

Chaque choix suit une contrainte du sujet ou du lab ; la colonne de droite dit ce qui a été écarté.

| Décision | Justification | Alternative écartée |
| --- | --- | --- |
| State Terraform local | Le projet du lab est éphémère | Backend GCS versionné avec verrouillage (recommandé en entreprise) |
| Clé SSH en métadonnées + `enable-oslogin = FALSE` | Indépendant des droits IAM du lab ; OS Login imposé par le projet ignorait les clés | OS Login |
| SSH limité à l'IP de l'opérateur (`/32`) | Le port 22 ouvert à Internet est scanné en permanence ; seul le poste Ansible s'y connecte | `0.0.0.0/0` (refusé par une validation Terraform) |
| VPC dédié en mode custom | Exigence du sujet, pas de sous-réseaux automatiques | Réseau `default` |
| IP publiques éphémères + inventaire dynamique | Aucune IP statique à maintenir, les VM sont retrouvées par leurs labels | IP statiques |
| Deux modules (`network`, `compute`) | Une responsabilité par module ; passer de 2 à 3 VM ne change qu'une variable | Ressources dans le `main.tf` racine |
| Nœuds Docker `debian:12` avec systemd, `privileged` | Même OS que les VM GCP ; systemd nécessaire aux modules `service` et aux handlers | Conteneurs sans systemd |
| Contrôleur : Python 3.12 + `pip install ansible` | Ansible ne tourne pas nativement sous Windows | WSL (accepté par le sujet) |
| Clés locales générées dans `local/ssh/` | Jamais committées (`.gitignore`) | Clés dans l'image |
| `ANSIBLE_CONFIG` explicite | Sous Docker Desktop, le dossier monté est modifiable par tous et Ansible ignore alors son `ansible.cfg` | `chmod` (sans effet sous Windows) |
| Valeurs de lab dans `terraform.tfvars` non versionné | Aucun identifiant de projet dans Git | Valeurs par défaut en dur |
| Inventaire cloud : copie générée `run.gcp.yml` | Le plugin ne lit pas la variable d'environnement dans `projects` ; le sujet interdit l'identifiant dans un fichier versionné mais autorise un fichier non versionné généré | Identifiant en dur dans `fleet.gcp.yml` |

Les rôles Ansible publics éventuels et leur justification sont à ajouter par le responsable Ansible.

## 8. Où regarder en cas de problème

**Diagnostic.** Journal de déploiement : `/var/log/fleetinfo/deploy.log`. Journaux nginx : `/var/log/nginx/`. Conteneurs : `docker compose -f local/docker-compose.yml ps` et `docker compose -f local/docker-compose.yml logs <service>`. Connexion : `ansible web -m ping --ask-vault-pass`. Infrastructure : `terraform -chdir=terraform output`.

| Symptôme | Cause | Solution |
| --- | --- | --- |
| `terraform apply` : erreur 412 `gcp.resourceLocations` | Région refusée par le lab | Renseigner `region` et `zone` autorisées dans `terraform.tfvars` (ex. `us-west1`, `us-west1-b`) |
| `terraform apply` : `Invalid value for field 'zone'` | Caractère parasite (une apostrophe) dans `terraform.tfvars` | Remettre `zone = "us-west1-b"`, puis relancer `apply` ; les VM sont recréées |
| `terraform plan` : `could not find default credentials` | Pas de connexion Google | `gcloud auth application-default login` |
| `localhost:8085` : `ERR_CONNECTION_REFUSED` pendant la connexion gcloud | La commande ne tourne plus, ou un VPN de navigateur interfère | Laisser la commande ouverte, désactiver le VPN, relancer |
| `gcloud` : `can't open file 'C:/c/Users/...'` | `MSYS_NO_PATHCONV=1` actif dans le terminal | `unset MSYS_NO_PATHCONV` ou ouvrir un nouveau terminal |
| `invalid_grant: Bad Request` dans l'inventaire | Lab expiré : le compte et le projet n'existent plus | Démarrer un nouveau lab, supprimer l'ancien state, se reconnecter avec le nouveau compte |
| SSH : `Permission denied (publickey)` sur une VM | OS Login imposé par le projet | `enable-oslogin = FALSE` (déjà dans le module `compute`) ; attendre environ une minute après le démarrage |
| SSH : `REMOTE HOST IDENTIFICATION HAS CHANGED` | VM recréée : nouvelle empreinte pour la même adresse IP | `ssh-keygen -R <IP>`, ou `-o UserKnownHostsFile=/dev/null` sur un lab jetable |
| Contrôleur `Exited (255)`, `exec format error` | Script d'entrée non exécutable depuis un montage Windows | Entrypoint lancé par `sh` (déjà en place) ; fins de ligne en LF |
| Ansible : `No inventory was parsed` | `ansible.cfg` ignoré (dossier world-writable) | `ANSIBLE_CONFIG` dans `docker-compose.yml` |
| Ansible : `Permission denied on resource project {{ lookup(...) }}` | Le plugin `gcp_compute` n'évalue pas la variable d'environnement dans `projects` | Utiliser `run.gcp.yml`, généré avec l'identifiant réel (commande `sed` de la section 4) |
| `Attempting to decrypt but no vault secrets found` | Mot de passe Vault non fourni | Ajouter `--ask-vault-pass` |
| `community.general.yaml callback has been removed` | Callback supprimé de la collection | `stdout_callback = ansible.builtin.default` et `callback_result_format = yaml` |
| Fuseau horaire : `still not desired state` | Debian normalise `UTC` en `Etc/UTC` | `common_timezone: "Etc/UTC"` |
| `.htpasswd` : `Failed to import ... passlib` | Bibliothèque absente de la cible | Installer `python3-passlib` avant la tâche |
| `set_fact` : `No key/value pairs provided` | `default(omit)` au premier déploiement | `default('')` et condition sur `previous_target` non vide |
| Déploiement : `/health` répond 404, retour arrière déclenché sur des VM neuves | nginx n'avait pas rechargé sa configuration avant le contrôle (le handler s'exécute en fin de play) | Tâche `meta: flush_handlers` au début du rôle `fleetinfo` (déjà en place) |
| Second passage : `changed=2` | Journal `deploy.log` et date de déploiement recalculés à chaque passage | `changed_when: false` sur le journal ; date de déploiement figée par release (fichier `deployed_at`) |
| Git : `refusing to merge unrelated histories` | Branches sans ancêtre commun | Recréer la branche à partir de `main`, ou `--allow-unrelated-histories` sur une branche de test |

## 9. Limites connues et dette technique

Le socle fonctionne en local de bout en bout et sur GCP : infrastructure, inventaire dynamique et déploiement de l'application sur deux VM neuves ont été validés sur un lab réel, avec un second passage à `changed=0`.
