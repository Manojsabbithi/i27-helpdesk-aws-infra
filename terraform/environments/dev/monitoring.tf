resource "aws_sns_topic" "monitoring_alerts" {
  name = "${var.project_name}-${var.environment}-monitoring-alerts"

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring-alerts"
  }
}

resource "aws_sns_topic_subscription" "monitoring_email" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

#
# EC2 CPU ALARMS
#

resource "aws_cloudwatch_metric_alarm" "jenkins_controller_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-controller-cpu-high"
  alarm_description   = "Jenkins Controller CPU usage is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = module.jenkins_controller.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-controller-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_agent_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-agent-cpu-high"
  alarm_description   = "Jenkins Agent CPU usage is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = module.jenkins_agent.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-agent-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "sonarqube_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-sonarqube-cpu-high"
  alarm_description   = "SonarQube CPU usage is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = module.sonarqube.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-sonarqube-cpu-high"
  }
}

#
# EC2 STATUS CHECK ALARMS
#

resource "aws_cloudwatch_metric_alarm" "jenkins_controller_status_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-controller-status-failed"
  alarm_description   = "Jenkins Controller EC2 status check failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = module.jenkins_controller.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-controller-status-failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_agent_status_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-agent-status-failed"
  alarm_description   = "Jenkins Agent EC2 status check failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = module.jenkins_agent.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-agent-status-failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "sonarqube_status_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-sonarqube-status-failed"
  alarm_description   = "SonarQube EC2 status check failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    InstanceId = module.sonarqube.instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-sonarqube-status-failed"
  }
}

#
# RDS ALARMS
#

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS MySQL CPU usage is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-free-storage-low"
  alarm_description   = "RDS MySQL free storage is below 5 GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions    = [aws_sns_topic.monitoring_alerts.arn]

  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-free-storage-low"
  }
}
