data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# 1. Bastion Host en subred pública (usa la llave vockey de AWS Academy)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = "vockey"
  associate_public_ip_address = true

  tags = { Name = "${var.project_name}-${var.environment}-bastion" }
}

# 2. Application Load Balancer (Multi-AZ público)
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-alb" }
}

# 3. Target Group principal (puerto 8080 para Spring Boot)
resource "aws_lb_target_group" "api_tg" {
  name     = "${var.project_name}-${var.environment}-api-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/actuator/health"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-404"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

# 4. Launch Template con Docker preinstalado
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = "vockey"

  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  user_data = base64encode(<<-SCRIPT
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  SCRIPT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-${var.environment}-app-node" }
  }
}

# 5. Auto Scaling Group (Multi-AZ privado enlazado al Target Group)
resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.project_name}-${var.environment}-asg"
  desired_capacity    = var.min_size
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.api_tg.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}
