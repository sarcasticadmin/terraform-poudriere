variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

# If wildcard it will always choose latest
variable "aws_ami_name_filter" {
  description = "Name filter for matching FreeBSD ami"
  default     = "FreeBSD 12.1-STABLE-amd64*"
}

variable "instance_size" {
  description = "ec2 instance size for building"
  default     = "t3a.large"
}

variable "vpc_id" {
  description = "VPC ID where poudriere instance will be spun up"
}

variable "aws_subnet_id" {
  description = "Subnet inside VPC to deploy poudriere in"
}

variable "ssh_key_name" {
  description = "Name for default ssh key to log in"
  default     = ""
}

variable "pkg_s3_bucket" {
  description = "S3 Bucket for which storing the pkgng pkgs and results"
}

variable "signing_s3_key" {
  description = "Private signing key s3 key location"
}

variable "signing_key" {
  description = "Private signing key local system key location"
  default     = "/usr/local/etc/ssl/keys/poudriere.key"
}

variable "max_memory_per_jail" {
  default = 2
}

variable "autoscaling_schedule_enable" {
  description = "Enable autoscaling schedule"
  default     = true
}

# Build the first of the month if enabled
variable "autoscaling_schedule_recurrence" {
  description = "cron string for how frequently poudriere should scale up"
  default     = "0 8 1 * *"
}

variable "poudriere_make" {
  default = ""
}

variable "poudriere_conf" {
  default = ""
}

variable "poudriere_list" {
  default = ""
}

variable "jail_version" {
  default = "12.1-RELEASE"
}

variable "auto_spindown" {
  default = true
}
