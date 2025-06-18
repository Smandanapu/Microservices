data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "mcp_demo_instance_1" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mcp_demo_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_access_profile.name

  tags = {
    Name = "mcp-demo-instance-1"
  }
}

resource "aws_instance" "mcp_demo_instance_2" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mcp_demo_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_access_profile.name

  tags = {
    Name = "mcp-demo-instance-2"
  }
}
