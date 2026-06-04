terraform {
  backend "s3" {
    bucket       = "damtechguy-tf-state-dev"
    key          = "client1/dev/platform/client1-platform-dev.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
