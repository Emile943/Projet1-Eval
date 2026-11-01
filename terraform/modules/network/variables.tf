#Ici on a les entrées du module réseau. pas de valeur par défaut (reçoit tout de la racine)

variable "network_name" {
  description = "Nom du VPC"
  type        = string
}

variable "subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
}

variable "subnet_cidr" {
  description = "Plage d'adresses IP du sous-réseau"
  type        = string
}

variable "region" {
  description = "Région GCP du sous-réseau"
  type        = string
}

variable "network_tag" {
  description = "Tag réseau ciblé par les règles firewall"
  type        = string
}

variable "ssh_source_ranges" {
  description = "IP autorisées à se connecter en SSH"
  type        = list(string)
}