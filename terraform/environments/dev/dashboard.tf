resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2

        properties = {
          markdown = "# i27 Helpdesk Dev Environment Monitoring\nCloudWatch dashboard for Jenkins, SonarQube and RDS."
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6

        properties = {
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
          region = "ap-south-2"
          period = 300
          stat   = "Average"

          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              module.jenkins_controller.instance_id,
              {
                label = "Jenkins Controller"
              }
            ],
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              module.jenkins_agent.instance_id,
              {
                label = "Jenkins Agent"
              }
            ],
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              module.sonarqube.instance_id,
              {
                label = "SonarQube"
              }
            ]
          ]

          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6

        properties = {
          title  = "EC2 Status Checks"
          view   = "timeSeries"
          region = "ap-south-2"
          period = 60
          stat   = "Maximum"

          metrics = [
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId",
              module.jenkins_controller.instance_id,
              {
                label = "Jenkins Controller"
              }
            ],
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId",
              module.jenkins_agent.instance_id,
              {
                label = "Jenkins Agent"
              }
            ],
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId",
              module.sonarqube.instance_id,
              {
                label = "SonarQube"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 6

        properties = {
          title  = "RDS CPU Utilization"
          view   = "timeSeries"
          region = "ap-south-2"
          period = 300
          stat   = "Average"

          metrics = [
            [
              "AWS/RDS",
              "CPUUtilization",
              "DBInstanceIdentifier",
              module.rds.db_instance_id,
              {
                label = "MySQL CPU"
              }
            ]
          ]

          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 6

        properties = {
          title  = "RDS Free Storage"
          view   = "timeSeries"
          region = "ap-south-2"
          period = 300
          stat   = "Average"

          metrics = [
            [
              "AWS/RDS",
              "FreeStorageSpace",
              "DBInstanceIdentifier",
              module.rds.db_instance_id,
              {
                label = "MySQL Free Storage"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 6

        properties = {
          title  = "RDS Connections"
          view   = "timeSeries"
          region = "ap-south-2"
          period = 300
          stat   = "Average"

          metrics = [
            [
              "AWS/RDS",
              "DatabaseConnections",
              "DBInstanceIdentifier",
              module.rds.db_instance_id,
              {
                label = "MySQL Connections"
              }
            ]
          ]
        }
      },

      {
        type   = "alarm"
        x      = 0
        y      = 14
        width  = 24
        height = 6

        properties = {
          title  = "CloudWatch Alarm Status"
          sortBy = "stateUpdatedTimestamp"

          alarms = [
            aws_cloudwatch_metric_alarm.jenkins_controller_cpu_high.arn,
            aws_cloudwatch_metric_alarm.jenkins_controller_status_failed.arn,
            aws_cloudwatch_metric_alarm.jenkins_agent_cpu_high.arn,
            aws_cloudwatch_metric_alarm.jenkins_agent_status_failed.arn,
            aws_cloudwatch_metric_alarm.sonarqube_cpu_high.arn,
            aws_cloudwatch_metric_alarm.sonarqube_status_failed.arn,
            aws_cloudwatch_metric_alarm.rds_cpu_high.arn,
            aws_cloudwatch_metric_alarm.rds_free_storage_low.arn
          ]
        }
      }
    ]
  })
}
