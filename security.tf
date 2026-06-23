resource "aws_security_group" "alb_sg" {
  name        = "production-alb-sg"
  description = "Allow public HTTP traffic to the Load Balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }  

  tags = {
    Name = "production-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "production-ecs-sg"
  description = "Allow traffic to web app ONLY from the ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name = "production-ecs-sg"
  }
}

resource "aws_iam_role" "ecs_execute_role" {
  name = "production-ecs-execute-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execute_policy" {
  role       = aws_iam_role.ecs_execute_role.name 
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}