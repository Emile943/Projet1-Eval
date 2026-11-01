#main.tf s'occupe de: VPC sous-réseau et firewall

#réseau privé VPC dans GCP. "false" pour créer nous meme le sous réseau
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

#sous réseau (les ip des vm sont ici)
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

#firewall http (port 80 ouvert aux vm qui ont le tag réseau)
resource "google_compute_firewall" "allow_http" {
  name          = "${var.network_name}-allow-http"
  network       = google_compute_network.vpc.name
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

#firewall ssh (port 22 pour son ip perso)
resource "google_compute_firewall" "allow_ssh" {
  name          = "${var.network_name}-allow-ssh"
  network       = google_compute_network.vpc.name
  source_ranges = var.ssh_source_ranges
  target_tags   = [var.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}


#google_compute_network.vpc.id : le sous-réseau référence le VPC par son identifiant, 
#ce qui dit à Terraform de créer le VPC en premier.
#target_tags : les règles s’appliquent uniquement aux VM portant ce tag
#source_ranges : HTTP est ouvert à tous, SSH seulement aux IP de la variable.