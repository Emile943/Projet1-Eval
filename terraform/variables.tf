#paramètres du projet. Les valeurs vont dans terraform.tfvars.

# --- Obligatoires : changent à chaque session de lab ---

variable "project_id" {
  description = "ID du projet GCP du lab"
  type        = string
}

variable "ssh_source_ranges" {
  description = "IP autorisées en SSH, par exemple [\"1.2.3.4/32\"]"
  type        = list(string)
}

# --- Optionnels : ont une valeur par défaut ---

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP"
  type        = string
  default     = "europe-west1-b"
}

variable "vm_count" {
  description = "Nombre de VM"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Type de machine"
  type        = string
  default     = "e2-small"
}

variable "network_name" {
  description = "Nom du VPC"
  type        = string
  default     = "fleet-vpc"
}

variable "subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
  default     = "fleet-subnet"
}

variable "subnet_cidr" {
  description = "Plage d'IP du sous-réseau"
  type        = string
  default     = "10.10.0.0/24"
}

variable "network_tag" {
  description = "Tag réseau commun aux VM"
  type        = string
  default     = "fleet-web"
}

variable "vm_name_prefix" {
  description = "Préfixe du nom des VM"
  type        = string
  default     = "fleet-web"
}

variable "labels" {
  description = "Labels des VM"
  type        = map(string)
  default = {
    env  = "cloud"
    role = "web"
    team = "plateforme"
  }
}

variable "ssh_user" {
  description = "Utilisateur Linux créé sur les VM"
  type        = string
  default     = "ansible"
}

variable "ssh_public_key_path" {
  description = "Chemin de la clé SSH publique sur ton PC"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}