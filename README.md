# Terraform Poudriere

[![CircleCI](https://circleci.com/gh/sarcasticadmin/terraform-poudriere/tree/master.svg?style=shield)](https://circleci.com/gh/sarcasticadmin/terraform-poudriere/tree/master)

Build your own `pkgng` repo and host it in AWS! This terraform module allows you to build pkgs on the fly
and the host the repo out of `s3`. Currently it will turn the `poudriere` autoscaling group to 0 after it
is done building.
> NOTE: Running this module in AWS will result in charges. Please be aware.

## Prereqs
### Generate signing key
Run the following outside and push it to s3 bucket
```
openssl genrsa -out ./poudriere.key 4096
openssl rsa -in ./poudriere.key -pubout -out ./poudriere.pub
aws s3 cp poudriere.key s3://<secure_bucket>/path/poudriere.key
```

## Config
[Example](https://github.com/sarcasticadmin/terraform-poudriere/tree/master/examples/simple/) of using the module:
```
module "poudriere" {
  source         = "./terraform-poudriere"
  aws_region     = "${var.aws_region}"
  vpc_id         = "${aws_vpc.default.id}"
  aws_subnet_id  = "${aws_subnet.public.id}"
  ssh_key_name   = "secret_ssh_key"
  pkg_s3_bucket  = "pkgs.example.com"
  signing_s3_key = "12345678-secure/poudriere/poudriere.key"
}
```

## AMI
Use the following `awscli` command to look up specific AMIs for
`FreeBSD 11.1` in region `us-east-1`:
```
aws ec2 describe-images --owners 782442783595 \
			--filters "Name=name,Values='FreeBSD 11.1-STABLE-amd64*'" "Name=root-device-type,Values=ebs" \
			--query 'sort_by(Images, &CreationDate)[].[ImageId, Name]'
```
> NOTE: the account id 782442783595 is the account thats hosting the FreeBSD
> offical images.

## Notes
### Troubleshooting
First check the boostrap.log on the `ec2` instance:
```
less /var/log/bootstrap.log
```

Check a failed build check compile flags in:
```
less /data/logs/bulk/
```

### Unsupport System

If your build fails and you notice the in build logs a similar error:

```
--End resource limits--
=======================<phase: check-sanity   >============================
/!\ ERROR: /!\

Ports Collection support for your FreeBSD version has ended, and no ports are
guaranteed to build on this system. Please upgrade to a supported release.

No support will be provided if you silence this message by defining
ALLOW_UNSUPPORTED_SYSTEM.

*** Error code 1

Stop.
```

This is due to the version of FreeBSD being built is no longer supported, you need to add the following to
your `make.conf`:

```
ALLOW_UNSUPPORTED_SYSTEM=yes
```

Please consider updating the version of the AMI and the jail you are building against
