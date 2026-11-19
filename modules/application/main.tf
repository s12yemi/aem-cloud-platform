data "aws_region" "current" {}
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  prefix = "${var.name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.prefix}-alb-"
  description = "Public HTTP lab entry point; use HTTPS for production"
  vpc_id      = var.vpc_id
  ingress {
    description = "Demo HTTP (not production TLS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "To application nodes"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = local.common_tags
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "app" {
  name_prefix = "${local.prefix}-app-"
  description = "Private application instances"
  vpc_id      = var.vpc_id
  ingress {
    description     = "HTTP only from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    description = "HTTPS for optional private AWS service endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
  lifecycle { create_before_destroy = true }
}

resource "aws_iam_role" "ec2" {
  name_prefix = "${local.prefix}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${local.prefix}-ec2-"
  role        = aws_iam_role.ec2.name
  tags        = local.common_tags
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.prefix}-app-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  update_default_version = true
  iam_instance_profile { arn = aws_iam_instance_profile.ec2.arn }
  vpc_security_group_ids = [aws_security_group.app.id]
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    environment = var.environment
  }))
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  monitoring { enabled = false }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }
  tags = local.common_tags
}

resource "aws_lb" "app" {
  name               = substr("${local.prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  enable_deletion_protection = false
  tags = local.common_tags
}

resource "aws_lb_target_group" "app" {
  name_prefix = "aem-"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = local.common_tags
  lifecycle { create_before_destroy = true }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
  tags = local.common_tags
}

resource "aws_autoscaling_group" "app" {
  name_prefix               = "${local.prefix}-asg-"
  vpc_zone_identifier       = var.private_subnet_ids
  min_size                  = 1
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.app.arn]
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_sns_topic" "alarms" {
  name = "${local.prefix}-alarms"
  tags = local.common_tags
}
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  alarm_name          = "${local.prefix}-healthy-hosts-low"
  alarm_description   = "Application ALB has no healthy targets (demo only)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alarms.arn]
  tags = local.common_tags
}

# Optional private connectivity for Session Manager without a NAT gateway.
# Interface endpoints have per-AZ hourly and data-processing charges.
resource "aws_security_group" "endpoints" {
  count       = var.enable_ssm_endpoints ? 1 : 0
  name_prefix = "${local.prefix}-endpoints-"
  description = "HTTPS from private EC2 application nodes to VPC endpoints"
  vpc_id      = var.vpc_id
  ingress {
    description     = "Instance to SSM interface endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  tags = local.common_tags
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags = merge(local.common_tags, { Name = "${local.prefix}-${each.key}" })
}
