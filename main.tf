### Provider definition

provider "aws" {
  region = "${var.aws_region}"
}

### Module Main

###LOAD BALANCER
  resource "aws_lb" "app-lb" {
    name               = "load-balancer"
    load_balancer_type = "application"
    security_groups    = [aws_security_group.lb_sg.id]
    subnets            = module.discovery.public_subnets
    tags = {
      Environment = "production"
    }
  }

  resource "aws_lb_target_group" "target-lb" {
    name     = "target-lb"
    port     = 8080
    protocol = "HTTP"
    vpc_id   = module.discovery.vpc_id
  }

  resource "aws_lb_listener" "listener-lb" {
    load_balancer_arn = aws_lb.app-lb.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.target-lb.arn
    }
  }

  resource "aws_security_group" "lb_sg" {
    vpc_id = "${module.discovery.vpc_id}"
    name = "lb_sg"
    description = "security group for autoscaling"
  
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    } 

    tags = {
      Name = "lb_sg"
    }
  }

###autoscalling
  resource "aws_security_group" "autoscalling" {
    vpc_id = "${module.discovery.vpc_id}"
    name = "elb"
    description = "security group for autoscalling"
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "autoscalling"
    }
  }

  resource "aws_security_group_rule" "autoscalling_http" {
    type        = "ingress"
    description = "Trafic for http"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    source_security_group_id = aws_security_group.lb_sg.id
    security_group_id = aws_security_group.autoscalling.id
  }

  data "aws_ami" "nat_ami" {
    most_recent      = true
    owners           = ["amazon"]

    filter {
      name   = "name"
      values = ["amzn2-ami-hvm-2.0.20210813.1-x86_64-gp2*"]
    }
  }

  resource "aws_key_pair" "deployer" {
    key_name   = "deployer"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCgb4KJX+Rtdm4rfAllGeviFxt1ONlj8zwbHaaoCIbpBr52re3xT1LND/tiQyool0qL9iZQIjd89//EPXNzlvNPXM+XJhN5A2zgTmHanAoJt+6N6LDJRCUYfRI9ooJzkWsraB7IqAPe1/lxb8OH0LZjS+OYoGn/0zVzlEeKZlSJSSf+GF98AHKcWxvUVpU/E++Q7fmsHdCCYDzxf6SGpUzgVC+WiIJN/u+c2uAIF0ZJ/mdgBZhOi85ISuVfnXeYKvxVfZry7jsLjVCJrLOBBdWCY5twHgsCdjKWDqkfVRVNoam/2e+QKsJnyxg8ajlYLVrQCiIXgf9S6KjMc4VtvOqP"
  }

  resource "aws_launch_template" "template_launcher" {
    name = "template_launcher"

    image_id = data.aws_ami.nat_ami.id

    instance_type = "t2.micro"

    key_name = aws_key_pair.deployer.key_name

    vpc_security_group_ids = [aws_security_group.autoscalling.id]

    tag_specifications {
      resource_type = "instance"

      tags = {
        Name = "template_launcher"
      }
    }

    user_data = filebase64("./example.sh")
  }

resource "aws_autoscaling_group" "bar" {
  vpc_zone_identifier = [for subnet in module.discovery.private_subnets : subnet]
  desired_capacity   = 1
  max_size           = 2
  min_size           = 1
  target_group_arns = [aws_lb_target_group.target-lb.arn]

  launch_template {
    id      = aws_launch_template.template_launcher.id
    version = "$Latest"
  }
}
