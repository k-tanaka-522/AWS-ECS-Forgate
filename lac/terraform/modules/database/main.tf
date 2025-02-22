# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.environment}-${var.app_name}-"
  family      = "mysql8.0"
  description = "Parameter group for ${var.app_name} RDS"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_filesystem"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name = "${var.environment}-${var.app_name}-db-parameter-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Random password for RDS
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets Manager for DB credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix = "${var.environment}/${var.app_name}/db-credentials-"
  description = "RDS database credentials for ${var.app_name}"

  tags = {
    Name = "${var.environment}-${var.app_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "mysql"
    host     = aws_db_instance.main.endpoint
    port     = 3306
    dbname   = var.db_name
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier_prefix    = "${var.environment}-${var.app_name}-"
  engine              = "mysql"
  engine_version      = "8.0.28"
  instance_class      = var.db_instance_class
  allocated_storage   = 20
  storage_type        = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.db_security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = var.environment != "prd"
  deletion_protection    = var.environment == "prd"

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  tags = {
    Name = "${var.environment}-${var.app_name}-rds"
  }
}

# CloudWatch Alarms (基本的なモニタリング)
resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "${var.environment}-${var.app_name}-db-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/RDS"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "RDS CPU utilization is too high"
  alarm_actions      = []  # SNSトピックのARNを設定する場合はここに追加

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
