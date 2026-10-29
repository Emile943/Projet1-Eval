#instancie les modules et les relie entre eux. Aucune ressource ici.

module "network" {
  source = "./modules/network"

  network_name      = var.network_name
  subnet_name       = var.subnet_name
  subnet_cidr       = var.subnet_cidr
  region            = var.region
  network_tag       = var.network_tag
  ssh_source_ranges = var.ssh_source_ranges
}

module "compute" {
  source = "./modules/compute"

  vm_count       = var.vm_count
  vm_name_prefix = var.vm_name_prefix
  machine_type   = var.machine_type
  zone           = var.zone
  network_tag    = var.network_tag
  labels         = var.labels
  ssh_user       = var.ssh_user
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  # Le lien entre les deux modules : les VM sont branchées sur le sous-réseau créé par "network".
  subnet_id = module.network.subnet_id
}

#module.network.subnet_id est le lien clé : Terraform en déduit qu’il doit créer le réseau avant les VM.
#file(...) lit la clé publique sur le PC, et trimspace retire le retour à la ligne final.