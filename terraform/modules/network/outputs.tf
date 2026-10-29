#valeurs qui sont remontées à la racine.

output "network_name" {
  description = "Nom du VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Nom du sous-réseau"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  description = "Identifiant du sous-réseau (pour brancher les VM)"
  value       = google_compute_subnetwork.subnet.id
}