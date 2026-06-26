resource "aws_lb" "app_alb" {
  name               = "production-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name        = "production-target-group"
  port        = 5000 
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip" 

  health_check {
    path                = "/health" 
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80" 
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


resource "aws_ecs_cluster" "app_cluster" {
  name = "production-cluster"
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-python-app"
  network_mode             = "awsvpc" 
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" 
  memory                   = "512" 
  execution_role_arn       = aws_iam_role.ecs_execute_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "ghcr.io/your-username/my-app:latest" 
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      environment = [
        { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address }
      ]
    }
  ])
}

resource "aws_ecs_service" "web_service" {
  name            = "production-web-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1 
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id] 
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false 
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "web-app" 
    container_port   = 5000
  }
}

output "application_load_balancer_dns" {
  value       = aws_lb.app_alb.dns_name
  description = "The public URL of your live production application"
}