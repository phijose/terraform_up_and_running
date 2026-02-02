provider "aws" {
    region = "ap-south-1"
}

resource "aws_instance" "example" {
    ami             = "ami-013f45d1553a97f57"
    instance_type   = "t3.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]
    user_data       = <<-EOF
                        #!/bin/bash
                        echo "Hello, World" > index.html
                        # Use Python's built-in server as a backup if busybox isn't there
                        nohup python3 -m http.server 8080 &
                      EOF
    user_data_replace_on_change = true
    tags            = {
        Name        = "terraform-ec2-example"
    }
}

resource "aws_security_group" "instance" {
    name            = "terraform-example-instance"
    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}