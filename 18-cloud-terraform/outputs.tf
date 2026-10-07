output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "AMI picked by the data source"
  value       = data.aws_ami.amazon_linux.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "Open this in a browser after apply"
  value       = "http://${aws_instance.web.public_dns}"
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app.bucket
}
