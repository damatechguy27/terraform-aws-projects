terraform {
  backend "s3" {
    bucket = "damtechguy-tf-state-dev"
    key    = "client1/dev/client1-dev.tfstate"
    region = "us-west-2"
    use_lockfile = true
    encrypt = true
  }
}