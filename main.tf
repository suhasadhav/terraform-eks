locals {
  path = "kubeconfig"
}

resource "aws_vpc" "eksvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eksvpc.id
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "priv" {
  vpc_id                  = aws_vpc.eksvpc.id
  count                   = 2
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = var.az[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "priv${count.index}"
  }
}

resource "aws_subnet" "pub" {
  vpc_id                  = aws_vpc.eksvpc.id
  count                   = 2
  cidr_block              = var.private_subnet_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "pub${count.index}"
  }
}
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "ng" {
  allocation_id     = aws_eip.nat_eip.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.pub[0].id
}


resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.eksvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "priv"
  }
}

resource "aws_route_table" "priv" {
  vpc_id = aws_vpc.eksvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ng.id
  }

  # route {
  #   ipv6_cidr_block        = "::/0"
  #   egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
  # }

  tags = {
    Name = "priv"
  }
}

resource "aws_route_table_association" "association" {
  count          = 2
  subnet_id      = aws_subnet.pub[count.index].id
  route_table_id = aws_route_table.pub.id
}

resource "aws_route_table_association" "association2" {
  count          = 2
  subnet_id      = aws_subnet.priv[count.index].id
  route_table_id = aws_route_table.priv.id
}