data "aws_availability_zones" "available" {}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  name    = "terraform-vpc"
  cidr    = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    ENV = "dev"
    TF  = "true"
  }
}

resource "aws_security_group" "first_security_group" {
  name        = "first_security_group"
  description = "our security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_network_interface" "public_interface" {
  count           = length(data.aws_availability_zones.available.names)
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.first_security_group.id]
}

resource "aws_network_interface" "private_interface" {
  count           = length(data.aws_availability_zones.available.names)
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.first_security_group.id]
}


resource "aws_instance" "custom_instances" {
  count         = length(data.aws_availability_zones.available.names)
  ami           = "ami-04e601abe3e1a910f"
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.public_interface[count.index].id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.private_interface[count.index].id
  }

  tags = {
    ENV = "dev"
    TF  = "true"
  }
}

resource "aws_eip" "custom_eip" {
  count = length(data.aws_availability_zones.available.names)
  vpc   = true
}

resource "aws_eip_association" "custom_eip_association" {
  count                = length(data.aws_availability_zones.available.names)
  network_interface_id = aws_network_interface.public_interface[count.index].id
  allocation_id        = aws_eip.custom_eip[count.index].id
}
