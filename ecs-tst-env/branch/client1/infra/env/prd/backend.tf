terraform {
  backend "s3" {
    bucket = "damtechguy-tf-state-prd"
    key    = "client1/prd/client1-prd.tfstate"
    region = "us-east-2"
    use_lockfile = true
    encrypt = true
  }
}