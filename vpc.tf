resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "production-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "production-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "production-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b" # Spread into data center B!
  map_public_ip_on_launch = true

  tags = {
    Name = "production-public-2"
  }
}

# Associate the new public subnet to our public internet highway route table
resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a" 

  tags = {
    Name = "production-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b" 

  tags = {
    Name = "production-private-2"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "production-public-rt"
  }
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_1.id 
  route_table_id = aws_route_table.public_rt.id
}

# 1. Allocate a Static Public IP (Elastic IP) for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]
}

# 2. Create the NAT Gateway inside your PUBLIC subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id # Must be in public!

  tags = {
    Name = "production-nat-gateway"
  }
}

# 3. ADDED: Create the missing Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "production-private-rt"
  }
}

# 4. Route outbound internet traffic from private subnets through the NAT Gateway
resource "aws_route" "private_internet_route" {
  route_table_id         = aws_route_table.private_rt.id 
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# 5. ADDED: Associate Private Subnet 1 with the Private Route Table
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

# 6. ADDED: Associate Private Subnet 2 with the Private Route Table
resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}