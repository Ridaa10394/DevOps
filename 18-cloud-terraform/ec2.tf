# Latest Amazon Linux 2023 AMI, looked up at plan time instead of hardcoding an ID
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <h1>Hello from Terraform - Session 19</h1>
    <p>Ridaa Mirza (24BCS10394)</p>
    HTML
    systemctl enable --now nginx
  EOT

  # Explicit dependency: the instance doesn't reference the route table at all,
  # but without the IGW route the user_data can't reach the package repos.
  # depends_on forces Terraform to finish the routing first.
  depends_on = [aws_route_table_association.public]

  tags = {
    Name = "${var.project_name}-web"
  }
}
