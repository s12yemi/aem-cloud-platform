output "alb_dns_name" { value = aws_lb.app.dns_name }
output "alb_arn" { value = aws_lb.app.arn }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "autoscaling_group_name" { value = aws_autoscaling_group.app.name }
output "alarm_name" { value = aws_cloudwatch_metric_alarm.unhealthy.alarm_name }
output "ssm_endpoint_ids" { value = { for name, endpoint in aws_vpc_endpoint.ssm : name => endpoint.id } }
