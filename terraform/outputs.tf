output "instance_id" {
  description = "EC2 instance ID; use it to retrieve the initial Windows password with the EC2 key pair."
  value       = aws_instance.windows.id
}

output "public_ip" {
  description = "Public IPv4 address of the Windows instance."
  value       = aws_instance.windows.public_ip
}

output "http_url" {
  description = "Public URL of the IIS demonstration page."
  value       = "http://${aws_instance.windows.public_ip}/"
}

output "rdp_endpoint" {
  description = "RDP endpoint; ingress is limited to admin_cidr."
  value       = "${aws_instance.windows.public_ip}:3389"
}

output "winrm_https_endpoint" {
  description = "WinRM HTTPS endpoint; ingress is limited to admin_cidr."
  value       = "${aws_instance.windows.public_ip}:5986"
}
