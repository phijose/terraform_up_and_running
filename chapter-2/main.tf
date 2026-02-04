terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.30.0"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
}

variable "listening_port" {
    type    = number
    default = 8080
}

resource "aws_security_group" "instance" {
    name            = "tf-ex-instance"
    ingress {
        from_port   = var.listening_port
        to_port     = var.listening_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_template" "example_lg" {
    image_id                = "ami-013f45d1553a97f57"
    instance_type           = "t3.micro"
    vpc_security_group_ids  = [aws_security_group.instance.id]
    user_data               = base64encode(<<-EOF
                                #!/bin/bash
                                echo "Hello, World" > index.html
                                # Use Python's built-in server as a backup if busybox isn't there
                                nohup python3 -m http.server ${var.listening_port} &
                              EOF
    )
}

resource "aws_autoscaling_group" "example_asg" {
    launch_template {
        id      = aws_launch_template.example_lg.id
        version = "$Latest"
    }
    vpc_zone_identifier     = data.aws_subnets.default.ids
    target_group_arns       = [aws_alb_target_group.asg.arn]
    health_check_type       = "ELB"
    max_size                = 10
    min_size                = 2
    tag {
        key                 = "Name"
        propagate_at_launch = true
        value               = "terraform_asg_example"
    }
}

resource "aws_lb" "example_lb" {
    name                = "terraform-example-lb"
    load_balancer_type  = "application"
    subnets             = data.aws_subnets.default.ids
    security_groups     = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn   = aws_lb.example_lb.arn
    port                = 80
    protocol            = "HTTP"
    default_action {
        type            = "fixed-response"
        fixed_response {
            content_type    = "text/plain"
            message_body    = "404: page not found"
            status_code     = 404
        }
    }
}

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_alb_target_group" "asg" {
    name        = "terraform-asg-example"
    port        = var.listening_port
    protocol    = "HTTP"
    vpc_id      = data.aws_vpc.default.id
    health_check {
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 15
        timeout             = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_alb_listener_rule" "asg" {
    listener_arn    = aws_lb_listener.http.arn
    priority        = 100
    condition {
        path_pattern {
            values = ["*"]
        }
    }
    action {
        type                = "forward"
        target_group_arn    = aws_alb_target_group.asg.arn
    }
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name    = "vpc-id"
        values   = [data.aws_vpc.default.id]
    }
}

output "alb_dns_name" {
    value       = aws_lb.example_lb.dns_name
    description = "The domain nameof the load balancer"
}
