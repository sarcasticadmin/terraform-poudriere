provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

module "poudriere" {
  #source         = "git::ssh://git@github.com/sarcasticadmin/terraform-poudriere.git"
  source         = "../../"
  aws_region     = "us-east-1"
  vpc_id         = "${data.aws_vpc.default.id}"
  aws_subnet_id  = "${element(data.aws_subnet_ids.all.ids, 0)}"
  pkg_s3_bucket  = "pkgs.example.com"
  signing_s3_key = "12345678-secure/poudriere/poudriere.key"
}
