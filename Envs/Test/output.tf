output "instance_hostname" {
  description = "Private DNS name of the EC2 instance."
  value       = aws_instance.app_server.private_dns
}

output "asr_gpu_public_ip" {
  value = aws_instance.asr_gpu.public_ip
}

output "asr_gpu_public_dns" {
  value = aws_instance.asr_gpu.public_dns
}
