provider "aws" {
  region = "ap-south-1"
}

variable "public_key_location" {}
variable "private_key_location" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a"]
 // private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

 // enable_nat_gateway = true
//  single_nat_gateway  = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "ssh_security_group" {
  name = "SSH_security_group"
  vpc_id = module.vpc.vpc_id

  ingress  {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    "Name" = "ssh-sg"
  } 
}



resource "aws_security_group" "efs_security_group" {
  name = "EFS Security Group"
  description = "EFS Security Group"
  vpc_id = module.vpc.vpc_id

  ingress {                                   
    description = "EFS Security Group"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}  

resource "aws_efs_file_system" "my_app_efs" {
  creation_token = "My Application EFS"

  tags = {
    Name = "My Application EFS"
  }
}

resource "aws_efs_mount_target" "one_azs" {
#  availability_zone_id = module.vpc.azs[0]
  file_system_id = aws_efs_file_system.my_app_efs.id
  subnet_id      = module.vpc.public_subnets[0]
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_key_pair" "ssh_key" {
  key_name = "demo"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "python-app-server" {
  ami = "ami-0e6329e222e662a52"
  instance_type = "t2.micro"

  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ssh_security_group.id]


  associate_public_ip_address = true
  key_name = aws_key_pair.ssh_key.key_name

 # user_data = file("entry-script.sh")

  connection = {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file(var.private_key_location)
  }   
  

  provisioner "remote-exec" {
   inline = [
     "sudo mount -t nfs4 ${aws_efs_mount_target.one_azs.ip_address}: / /var/www/html/"
   ]

  }

 

  tags = {
    "Name" = "server"
  }
  
 
}