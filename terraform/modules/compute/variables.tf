#entrées du module VM.
#taille du disque et l’image écrites dans main.tf

variable "vm_count" {
  description = "Nombre de VM à créer"
  type        = number
}

variable "vm_name_prefix" {
  description = "Préfixe du nom des VM (suivi de -1, -2, etc...)"
  type        = string
}

variable "machine_type" {
  description = "Type de machine GCP"
  type        = string
}

variable "zone" {
  description = "Zone GCP des VM"
  type        = string
}

variable "subnet_id" {
  description = "Sous-réseau où brancher les VM"
  type        = string
}

variable "network_tag" {
  description = "Tag réseau commun aux VM"
  type        = string
}

variable "labels" {
  description = "Labels des VM (env, role, team)"
  type        = map(string)
}

variable "ssh_user" {
  description = "Utilisateur Linux créé sur les VM"
  type        = string
}

variable "ssh_public_key" {
  description = "Contenu de la clé publique SSH"
  type        = string
}