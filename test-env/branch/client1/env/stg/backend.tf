terraform {
  backend "s3" {
    bucket = "damtechguy-tf-state-stg"
    key    = "client1/stg/client1-stg.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}