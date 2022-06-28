terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


locals {
  vpc        = "vpc-0afb3c676d3d9d4c7"
  subnet     = "subnet-04b15c492caaac28f"
  subnet-alt = "subnet-04de6d5aa012dcda1"
}


resource "aws_security_group" "data" {
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description = ""
      from_port   = 5432
      ipv6_cidr_blocks = [
        "::/0",
      ]
      prefix_list_ids = []
      protocol        = "tcp"
      security_groups = []
      self            = false
      to_port         = 5432
    },

    {
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups = [
        aws_security_group.service.id,
      ]
      self    = true
      to_port = 0
    },
  ]
  vpc_id = local.vpc

  timeouts {}

  lifecycle {
    ignore_changes = [
      description
    ]
  }
}



resource "aws_security_group" "service" {
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description = ""
      from_port   = 22
      ipv6_cidr_blocks = [
        "::/0",
      ]
      prefix_list_ids = []
      protocol        = "tcp"
      security_groups = []
      self            = false
      to_port         = 22
    },
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description = ""
      from_port   = 443
      ipv6_cidr_blocks = [
        "::/0",
      ]
      prefix_list_ids = []
      protocol        = "tcp"
      security_groups = []
      self            = false
      to_port         = 443
    },
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    }
  ]
  vpc_id = local.vpc

  timeouts {}

  lifecycle {
    ignore_changes = [
      description
    ]
  }
}


resource "aws_ecs_cluster" "cluster" {
  capacity_providers = []
  name               = "cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_key_pair" "ecs" {
  key_name   = "ecs"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDR2lxFNQcWwkqJqrDvk4FNtD6PISN415RhJVVQ5fqQhc2dfEB4AUqg25NAs4Aj8kSSEg+FpR0xboOnwvNn3fvgiFioXzqmyLzPMYGW3IeyWFlV93VUWL7yIcGF0WdeSX2AFGCPfHreS1nrTj8c00dOm/JMxDPNNWDDG488B7jbnwz8EiJOyynx3dpfQEK5WaIVZSvWr2sICg02gCspY6kk3A8aR9/kYFauQRAwKLq0OuFpF6V/Zgv5EBFeqZfj9EYygpu4lxYRq7qrlszIABtvNsPJ3jou/G56wVcPjLYDwjFt/iFYUdxKK4U50042ZocDIxzSceMhic2hna4PRryd reyrodrigues@DESKTOP-LJ3G9EQ"
}

resource "aws_autoscaling_group" "cluster" {
  default_cooldown          = 300
  desired_capacity          = 2
  enabled_metrics           = []
  health_check_grace_period = 0
  health_check_type         = "EC2"
  launch_configuration      = aws_launch_configuration.cluster.id
  load_balancers            = []
  max_instance_lifetime     = 0
  max_size                  = 2
  metrics_granularity       = "1Minute"
  min_size                  = 0
  name                      = "auto-scaling-group-cluster"
  protect_from_scale_in     = false
  suspended_processes       = []
  target_group_arns         = []
  termination_policies      = []
  vpc_zone_identifier = [
    local.subnet,
    local.subnet-alt,
  ]
  force_delete              = false
  wait_for_capacity_timeout = "10m"

  timeouts {}
}

resource "aws_iam_instance_profile" "clusterInstanceProfile" {
  name = "clusterInstanceProfile"
  role = aws_iam_role.ecs-service-role.name
}


resource "aws_launch_configuration" "cluster" {
  associate_public_ip_address = true
  ebs_optimized               = false
  enable_monitoring           = true
  image_id                    = "ami-06634c1b99d35f2c7"
  instance_type               = "t3.large"
  key_name                    = aws_key_pair.ecs.key_name
  iam_instance_profile        = aws_iam_instance_profile.clusterInstanceProfile.name
  security_groups = [
    aws_security_group.service.id,
  ]

  user_data = templatefile("user_data.sh", { ecs_cluster = aws_ecs_cluster.cluster.name })

  ebs_block_device {
    delete_on_termination = false
    device_name           = "/dev/xvdcz"
    encrypted             = false
    iops                  = 0
    no_device             = false
    volume_size           = 22
    volume_type           = "gp2"
  }
}



resource "aws_db_subnet_group" "db-subnet-group" {
  name = "db-subnet-group"
  subnet_ids = [
    local.subnet,
    local.subnet-alt,
  ]
}


resource "aws_db_instance" "spoke" {
  count                               = 0
  allocated_storage                   = 20
  auto_minor_version_upgrade          = true
  availability_zone                   = "us-east-1b"
  backup_retention_period             = 3
  ca_cert_identifier                  = "rds-ca-2019"
  copy_tags_to_snapshot               = true
  db_subnet_group_name                = aws_db_subnet_group.db-subnet-group.name
  delete_automated_backups            = true
  deletion_protection                 = false
  enabled_cloudwatch_logs_exports     = []
  engine                              = "postgres"
  engine_version                      = "13.4"
  iam_database_authentication_enabled = false
  identifier                          = "spoke"
  instance_class                      = "db.t3.micro"
  maintenance_window                  = "fri:08:50-fri:09:20"
  multi_az                            = false
  option_group_name                   = "default:postgres-13"
  parameter_group_name                = "default.postgres13"
  port                                = 5432
  publicly_accessible                 = true
  security_group_names                = []
  skip_final_snapshot                 = true
  storage_encrypted                   = false
  storage_type                        = "gp2"
  username                            = "postgres"
  password                            = "postgres"
  vpc_security_group_ids = [
    aws_security_group.data.id,
  ]

  timeouts {}

  lifecycle {
    ignore_changes = [snapshot_identifier]
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "/ecs/web-app"
}

resource "aws_iam_role" "ecs-service-role" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
          }
          Sid = ""
        },
      ]
      Version = "2008-10-17"
    }
  )
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "ecsServiceRole"
  path                  = "/"
  tags                  = {}
}

resource "aws_iam_role_policy_attachment" "ecs-policy" {
  role       = aws_iam_role.ecs-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2-policy" {
  role       = aws_iam_role.ecs-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "cw-policy" {
  role       = aws_iam_role.ecs-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_ecs_service" "spoke" {
  cluster                            = aws_ecs_cluster.cluster.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  enable_ecs_managed_tags            = false
  health_check_grace_period_seconds  = 0
  iam_role                           = aws_iam_role.ecs-service-role.name
  launch_type                        = "EC2"
  name                               = "spoke"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  task_definition                    = "${aws_ecs_task_definition.web.family}:${aws_ecs_task_definition.web.revision}"

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    container_name   = "web"
    container_port   = 80
    target_group_arn = module.load_balancer.target_group.arn
  }

  ordered_placement_strategy {
    field = "attribute:ecs.availability-zone"
    type  = "spread"
  }

  ordered_placement_strategy {
    field = "instanceId"
    type  = "spread"
  }

  timeouts {}

  lifecycle {
    ignore_changes = [
      task_definition,
    ]
  }
}

resource "aws_ecs_task_definition" "web" {
  container_definitions    = file("./data/web-task-definition.json")
  cpu                      = 1024
  family                   = "web"
  memory                   = 1024
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs-service-role.arn
  task_role_arn            = aws_iam_role.ecs-service-role.arn
}



module "load_balancer" {
  source         = "./modules/LoadBalancers"
  security_group = aws_security_group.service
  subnets = {
    main      = { id = local.subnet }
    secondary = { id = local.subnet-alt }
  }
  vpc = {
    id  = local.vpc
    arn = local.vpc
  }
  domain_name = "spoke.reyrodrigues.me"
  lb_name     = "spoke-lb"
}
