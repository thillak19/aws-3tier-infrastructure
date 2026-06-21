terraform {
  backend "s3" {
    bucket         = "thillak-terraform-state-2026"
    key            = "threetier/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}