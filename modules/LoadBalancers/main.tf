
variable "security_group" {}
variable "subnets" {}
variable "vpc" {}
variable "domain_name" {}
variable "lb_name" {}

resource "aws_lb" "lb" {
  drop_invalid_header_fields = false
  enable_deletion_protection = false
  enable_http2               = true
  idle_timeout               = 60
  internal                   = false
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  name                       = var.lb_name
  security_groups = [
    var.security_group.id
  ]
  subnets = [
    var.subnets.main.id,
    var.subnets.secondary.id
  ]
  tags = {}

  timeouts {}
}


resource "aws_lb_target_group" "lb_tg" {
  deregistration_delay          = 300
  load_balancing_algorithm_type = "round_robin"
  port                          = 80
  protocol                      = "HTTP"
  slow_start                    = 0
  tags                          = {}
  target_type                   = "instance"
  vpc_id                        = var.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  stickiness {
    cookie_duration = 86400
    enabled         = false
    type            = "lb_cookie"
  }
}



resource "aws_lb_listener" "lb_listener_http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"


  default_action {
    order            = 1
    target_group_arn = aws_lb_target_group.lb_tg.arn
    type             = "forward"
  }

  #   default_action {
  #     order = 1
  #     type  = "redirect"

  #     redirect {
  #       host        = "#{host}"
  #       path        = "/#{path}"
  #       port        = "443"
  #       protocol    = "HTTPS"
  #       query       = "#{query}"
  #       status_code = "HTTP_302"
  #     }
  #   }

  timeouts {}
}

# resource "aws_lb_listener" "lb_listener_https" {
#   certificate_arn   = aws_acm_certificate.certificate.id
#   load_balancer_arn = aws_lb.lb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"

#   default_action {
#     order            = 1
#     target_group_arn = aws_lb_target_group.lb_tg.arn
#     type             = "forward"
#   }

#   timeouts {}
# }


# resource "aws_acm_certificate" "certificate" {
#   domain_name = var.domain_name
#   validation_method = "DNS"

#   tags = {
#   }

#   lifecycle {
#     ignore_changes = [domain_name, validation_method]
#   }
# }

# output "target_group" {
#   value = aws_lb_target_group.lb_tg
# }


output "target_group" {
  value = aws_lb_target_group.lb_tg
}
