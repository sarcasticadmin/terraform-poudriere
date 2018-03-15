data "aws_ami" "freebsd" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.aws_ami_name_filter}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["118940168514"] # Account for FreeBSD hosted AMIs
}

resource "aws_security_group" "poudriere" {
  name_prefix = "poudriere"
  vpc_id      = "${var.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "poudriere_conf" {
  template = "${file("${path.module}/config/poudriere.conf.tmpl")}"

  vars {
    SIGNING_KEY = "${var.signing_key}"
    MAX_MEMORY  = "${var.max_memory_per_jail}"
  }
}

data "archive_file" "poudriere_zip" {
  type        = "zip"
  output_path = "${path.module}/userdata.zip"

  source {
    content = <<EOF
>/etc/terraform.facts
AMI_NAME="${data.aws_ami.freebsd.name}"
SIGNING_S3_KEY=${var.signing_s3_key}
SIGNING_KEY=${var.signing_key}
S3_BUCKET=${var.pkg_s3_bucket}
EOF

    filename = "terraform.facts"
  }

  source {
    content = <<EOF
>/usr/local/etc/poudriere.d/make.conf
${file("${path.module}/config/make.conf")}
EOF

    filename = "make.conf"
  }

  source {
    content = <<EOF
>/usr/local/etc/poudriere.conf
${data.template_file.poudriere_conf.rendered}
EOF

    filename = "poudriere.conf"
  }

  source {
    content = <<EOF
>/usr/local/etc/poudriere-list
${file("${path.module}/config/poudriere-list")}
EOF

    filename = "poudriere-list"
  }

  # Bootstrap needs to be lexigraphically last since all other files in
  # the archive are required for the bootstrap to run
  source {
    content  = "${file("${path.module}/bootstrap/poudriere_userdata.sh")}"
    filename = "zuserdata.sh"
  }
}

resource "aws_launch_configuration" "poudriere" {
  name_prefix       = "poudriere"
  image_id          = "${data.aws_ami.freebsd.id}"
  instance_type     = "${var.instance_size}"
  ebs_optimized     = false
  enable_monitoring = false

  lifecycle {
    create_before_destroy = true
  }

  security_groups      = ["${aws_security_group.poudriere.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.poudriere.name}"
  key_name             = "${var.ssh_key_name}"
  user_data            = "${base64encode(file("${data.archive_file.poudriere_zip.output_path}"))}"
}

resource "aws_autoscaling_group" "poudriere" {
  name_prefix               = "poudriere"
  max_size                  = "1"
  min_size                  = "0"
  force_delete              = true
  health_check_grace_period = 300
  launch_configuration      = "${aws_launch_configuration.poudriere.name}"
  vpc_zone_identifier       = ["${var.aws_subnet_id}"]

  tag {
    key                 = "Name"
    value               = "poudriere"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "role"
    value               = "poudriere"
    propagate_at_launch = "true"
  }
}

resource "aws_autoscaling_schedule" "poudriere" {
  count = "${var.autoscaling_schedule_enable ? 1 : 0}"

  scheduled_action_name  = "periodic_poudriere_scaleup"
  autoscaling_group_name = "${aws_autoscaling_group.poudriere.name}"
  min_size               = -1
  max_size               = -1
  desired_capacity       = 1
  recurrence             = "${var.autoscaling_schedule_recurrence}"
}
