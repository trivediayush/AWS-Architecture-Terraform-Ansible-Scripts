resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-fe-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-api-tg"
  port        = 5678
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "bl" {
  name        = "${var.project_name}-bl-tg"
  port        = 5679
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Mosquitto WebSockets listener (port 9001). A plain HTTP GET to a websockets
# listener does not reliably return 2xx - depending on the ws library it may
# be 4xx, 5xx, 101, or a bare upgrade response. The matcher accepts ANY HTTP
# status: "something HTTP answers on the WS port" is the right signal. Deeper
# protocol validation needs a real WS-capable MQTT client (see README).
resource "aws_lb_target_group" "mqtt_ws" {
  name        = "${var.project_name}-mqtt-tg"
  port        = 9001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/mqtt"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-599"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# HTTP only - demo configuration. Do not add HTTPS without a real ACM cert + domain.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_lb_listener_rule" "bl" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bl.arn
  }

  condition {
    path_pattern {
      values = ["/bl/*"]
    }
  }
}

# "/mqtt*" (not "/mqtt/*") so the bare "/mqtt" path also matches - MQTT.js uses
# "/mqtt" as its default WebSocket path.
resource "aws_lb_listener_rule" "mqtt_ws" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mqtt_ws.arn
  }

  condition {
    path_pattern {
      values = ["/mqtt*"]
    }
  }
}
