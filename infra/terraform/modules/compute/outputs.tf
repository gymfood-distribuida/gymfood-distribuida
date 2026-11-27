output "alb_dns_name" { value = aws_lb.main.dns_name }
output "bastion_public_ip" { value = aws_instance.bastion.public_ip }
output "asg_name" { value = aws_autoscaling_group.app_asg.name }
