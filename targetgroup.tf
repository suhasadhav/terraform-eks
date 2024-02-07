resource "aws_lb_target_group" "tg" {
  count = 2
  name     = "tg-${count.index}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.eksvpc.id
  target_type = "ip"
}

