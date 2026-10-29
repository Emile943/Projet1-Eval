#valeurs remontées à la racine.

output "vm_names" {
  description = "Noms des VM"
  value       = google_compute_instance.vm[*].name
}

output "public_ips" {
  description = "IP publique de chaque VM"
  value       = { for vm in google_compute_instance.vm : vm.name => vm.network_interface[0].access_config[0].nat_ip }
}

#public_ips fabrique une table nom -> IP. Elle sera affichée par terraform output.
#ça permet à ne pas avoir a chercher les ip dans la console GCP