output "Prometheus_SecGrp_ID" {
  description = "Security Group ID for Prometheus Server"
  value       = try(aws_security_group.Prometheus_sg.id, "")
}

output "Prometheus_Server_Public_IP" {
  description = "Public IP of the Prometheus Server"
  value       = aws_instance.prometheus_Server.public_ip
}


############
### Key Pair
############
output "private_key" {
  value     = tls_private_key.DemoPrivateKey.private_key_pem
  sensitive = true
}
