data "aws_availability_zones" "this" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_subnet" "public" {
  for_each                = { for index, name in data.aws_availability_zones.this.names : name => index }
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = "10.0.${each.value}.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  for_each          = { for index, name in data.aws_availability_zones.this.names : name => index }
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = "10.0.${each.value + 3}.0/24"
}
