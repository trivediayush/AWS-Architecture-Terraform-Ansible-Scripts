# Sizing: 4 tasks x 256 CPU / 512 MiB = 1024 CPU units, 2 GiB total.
# c6g.xlarge exposes 4096 CPU units and ~7.5 GiB to ECS after agent/OS
# reservation, so all four tasks fit with large headroom on ONE host - the
# spread placement strategy (see ecs-services.tf) distributes them anyway.

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true
      cpu       = 256
      memory    = 384

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        # nginx:alpine ships busybox wget; no curl, no bash.
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_image
      essential = true
      cpu       = 256
      memory    = 384

      environment = [
        { name = "PORT", value = "5678" },
        { name = "SERVICE_NAME", value = "api" }
      ]

      portMappings = [
        {
          containerPort = 5678
          hostPort      = 5678
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        # node:alpine-based image: busybox wget is present, curl is not.
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:5678/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "bl" {
  family                   = "${var.project_name}-bl"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "bl"
      image     = var.bl_image
      essential = true
      cpu       = 256
      memory    = 384

      environment = [
        { name = "PORT", value = "5679" },
        { name = "SERVICE_NAME", value = "bl" }
      ]

      portMappings = [
        {
          containerPort = 5679
          hostPort      = 5679
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:5679/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "bl"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "mqtt" {
  family                   = "${var.project_name}-mqtt"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "mqtt"
      image     = var.mqtt_image
      essential = true
      cpu       = 256
      memory    = 384

      # eclipse-mosquitto is alpine-based (sh present). The stock image has no
      # websockets listener and a config file cannot be mounted without a
      # volume, so generate one at container start (global options BEFORE the
      # listener lines - options after a listener are listener-scoped):
      #   1883 = native MQTT/TCP (internal VPC only)
      #   9001 = MQTT over WebSockets (reachable via the ALB /mqtt* rule)
      # Anonymous access is enabled because this is a demo broker with no real
      # devices - never run this against production clients.
      entryPoint = ["sh", "-c"]
      command = [
        "printf 'allow_anonymous true\\nuser mosquitto\\nlog_type all\\nlistener 1883\\nlistener 9001\\nprotocol websockets\\n' > /mosquitto/config/mosquitto.conf && exec /docker-entrypoint.sh mosquitto -c /mosquitto/config/mosquitto.conf"
      ]

      portMappings = [
        {
          containerPort = 1883
          hostPort      = 1883
          protocol      = "tcp"
        },
        {
          containerPort = 9001
          hostPort      = 9001
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        # Broker-aware check: subscribe to the broker's own $SYS/uptime topic.
        # mosquitto publishes $SYS every ~10s, so -W 15 is reliable.
        # NOTE: ECS does NOT unescape '$$' inside healthCheck commands -
        # writing '$$SYS' here makes the broker see a literal '$$SYS' topic
        # and the check times out. Use plain '$SYS' (single-quoted).
        command     = ["CMD-SHELL", "mosquitto_sub -t '$SYS/broker/uptime' -C 1 -W 15 || exit 1"]
        interval    = 30
        timeout     = 20
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mqtt"
        }
      }
    }
  ])
}
