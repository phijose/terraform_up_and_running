terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.30.0"
    }
  }
  backend "s3" {
    bucket        = "terraform-up-and-running-state-phijo"
    region        = "ap-south-1"
    key           = "stage/services/webserver-cluster/terraform.tfstate"
    use_lockfile  = true
    encrypt       = true
  }
}

provider "aws" {
  region = "ap-south-1"
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
  user_data               = base64encode(templatefile("user-data.sh", {
    listening_port  = var.listening_port
    db_address      = data.terraform_remote_state.db.outputs.address
    db_port         = data.terraform_remote_state.db.outputs.port
  }))
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

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket  = "terraform-up-and-running-state-phijo"
    region  = "ap-south-1"
    key     = "stage/data-stores/mysql/terraform.tfstate"
  }
}