# Create a CloudWatch Log Group for Nginx access logs
resource "aws_cloudwatch_log_group" "nginx_access_logs" {
  name              = "/ec2/nginx/access"
  retention_in_days = 30 # the logs will be saved in CloudWatch for 30 days, after which they will be automatically deleted. 
  #Adjust this value based on your log retention requirements and compliance policies.

  tags = {
    Name        = "NginxAccessLogs-${var.environment}"
    Environment = var.environment
  }
}

# Create a CloudWatch Log Group for Nginx error logs
resource "aws_cloudwatch_log_group" "nginx_errors_logs" {
  name              = "/ec2/nginx/error"
  retention_in_days = 30 # the logs will be saved in CloudWatch for 30 days, after which they will be automatically deleted. 
  #Adjust this value based on your log retention requirements and compliance policies.

  tags = {
    Name        = "NginxErrorsLogs-${var.environment}"
    Environment = var.environment
  }

}

# Create a CloudWatch Log Group for ec2 system logs
resource "aws_cloudwatch_log_group" "ec2_system_logs" {
  name              = "/ec2/system"
  retention_in_days = 30 # the logs will be saved in CloudWatch for 30 days, after which they will be automatically deleted. 
  #Adjust this value based on your log retention requirements and compliance policies.

  tags = {
    Name        = "EC2SystemLogs-${var.environment}"
    Environment = var.environment
  }
}


# Store the CloudWatch Agent configuration in SSM Parameter Store so that the EC2 instances can retrieve it at startup
resource "aws_ssm_parameter" "cloudwatch_config" {
  name = "/ec2/${var.environment}/cloudwatch-agent-config"
  type = "String"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }

    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/nginx/access.log"
              log_group_name  = aws_cloudwatch_log_group.nginx_access_logs.name
              log_stream_name = "{instance_id}"
              timezone        = "UTC"
            },
            {
              file_path       = "/var/log/nginx/error.log"
              log_group_name  = aws_cloudwatch_log_group.nginx_errors_logs.name
              log_stream_name = "{instance_id}"
              timezone        = "UTC"
            },
            {
              file_path       = "/var/log/cloud-init-output.log"
              log_group_name  = aws_cloudwatch_log_group.ec2_system_logs.name
              log_stream_name = "{instance_id}"
              timezone        = "UTC"
            }
          ]
        }
      }
    }

    metrics = {
      metrics_collected = {
        cpu = {
          measurement                 = ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
          totalcpu                    = true
        }
        mem = {
          measurement                 = ["mem_used_percent", "mem_available_percent"]
          metrics_collection_interval = 60
        }
        disk = {
          measurement                 = ["disk_used_percent", "disk_free"]
          metrics_collection_interval = 60
          resources                   = ["/"]
        }
      }
    }
  })

  tags = {
    Name        = "cloudwatch-agent-config"
    Environment = var.environment
  }
}

