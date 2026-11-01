#VM Compute Engine.

resource "google_compute_instance" "vm" {
  count = var.vm_count

  name         = "${var.vm_name_prefix}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  # Le tag réseau déclenche les règles firewall, les labels servent à l'inventaire Ansible.
  tags   = [var.network_tag]
  labels = var.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    #IP publique éphémère (permet de pas avoir d'IP statique à gérer).
    access_config {}
  }

  # La clé PUBLIQUE est copiée dans la VM. La clé privée reste sur ton PC.
  # enable-oslogin = FALSE : sans cela, un projet qui impose OS Login ignorerait ces clés.
  metadata = {
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
    enable-oslogin = "FALSE"
  }
}

#count = var.vm_count : Terraform crée ce bloc autant de fois que demandé. 
#Passer de 2 à 3 VM revient à changer un chiffre, sans toucher au module.
#count.index + 1 : donne VM-google-1, VM-google-2, etc...
#image = "debian-cloud/debian-12" : image Debian 12 officielle de Google
#ssh-keys : au démarrage, Google crée l’utilisateur et installe la clé.
#Ansible pourra ensuite s’y connecter.