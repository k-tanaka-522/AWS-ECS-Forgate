# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight           = 1
  }

  tags = {
    Name = "${var.environment}-${var.app_name}-cluster"
  }
}

# Task Execution Role
resource "aws_iam_role" "task_execution" {
  name = "${var.environment}-${var.app_name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.app_name}-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role
resource "aws_iam_role" "task" {
  name = "${var.environment}-${var.app_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.app_name}-task-role"
  }
}

# Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.environment}-${var.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = var.task_cpu
  memory                  = var.task_memory
  execution_role_arn      = aws_iam_role.task_execution.arn
  task_role_arn          = aws_iam_role.task.arn
  
  runtime_platform {
    operating_system_family = "LINUX_64"
    cpu_architecture       = "X86_64"
    operating_system_version = "2023"
  }

  container_definitions = jsonencode([
    {
      name  = "wordpress"
      image = var.container_image
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DB_NAME"
          value = "wordpress"
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = "wordpress"
        },
        {
          name  = "WORDPRESS_DEBUG"
          value = "true"
        },
        {
          name  = "WORDPRESS_SITEURL"
          value = "https://${var.environment}.tk-niigata.com"
        },
        {
          name  = "WORDPRESS_HOME"
          value = "https://${var.environment}.tk-niigata.com"
        }
      ]
      secrets = [
        {
          name      = "WORDPRESS_DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/db-password"
        },
        {
          name      = "WORDPRESS_DB_HOST"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/db-host"
        },
        {
          name      = "COGNITO_USER_POOL_ID"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/cognito-pool-id"
        },
        {
          name      = "COGNITO_CLIENT_ID"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/cognito-client-id"
        },
        {
          name      = "AWS_ACCESS_KEY_ID"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/aws-access-key"
        },
        {
          name      = "AWS_SECRET_ACCESS_KEY"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/wordpress/aws-secret-key"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.environment}-${var.app_name}-task-definition"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.environment}-${var.app_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.environment}-${var.app_name}-log-group"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets           = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prd"

  tags = {
    Name = "${var.environment}-${var.app_name}-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-${var.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher            = "200"
  }

  tags = {
    Name = "${var.environment}-${var.app_name}-target-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name       = "dev.tk-niigata.com"
  validation_method = "DNS"

  tags = {
    Name = "${var.environment}-${var.app_name}-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ALB HTTP Listener (Redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.environment}-${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = true

  tags = {
    Name = "${var.environment}-${var.app_name}-service"
  }

  depends_on = [aws_lb_listener.http]
}

# Auto Scaling
resource "aws_appautoscaling_target" "main" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.environment}-${var.app_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Data Sources
data "aws_region" "current" {}
