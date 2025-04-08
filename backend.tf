terraform {
  backend "s3" {
    bucket  = "terraform-state-geekyrbhalala"
    key     = "vpc-with-public-ec2/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}