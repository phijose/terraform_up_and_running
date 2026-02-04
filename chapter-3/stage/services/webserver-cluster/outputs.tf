output "alb_dns_name" {
  value       = aws_lb.example_lb.dns_name
  description = "The domain nameof the load balancer"
}