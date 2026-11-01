#valeurs affichées par "terraform output" après l'apply.

output "network_name" {
  description = "Nom du VPC"
  value       = module.network.network_name
}

output "subnet_name" {
  description = "Nom du sous-réseau"
  value       = module.network.subnet_name
}

output "vm_names" {
  description = "Noms des VM"
  value       = module.compute.vm_names
}

output "vm_public_ips" {
  description = "IP publique de chaque VM"
  value       = module.compute.public_ips
}