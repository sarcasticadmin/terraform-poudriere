#!/bin/sh
exec >> /var/log/bootstrap.log
exec 2>&1

set -ex
export PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/root/bin

# File includes terraform info to source
# like AMI NAME, SIGNING_KEY,
# S3_BUCKET, SIGNING_S3_KEY
# shellcheck disable=SC1091
. /etc/terraform.facts
CURL_FLAGS="-L --connect-timeout 10 --max-time 120"
ARCH=$(uname -p)
ABI="FreeBSD:$(echo "${JAIL_VERSION}" | cut -d '.' -f1):${ARCH}"

install_pkgs(){
  env ASSUME_ALWAYS_YES=YES pkg bootstrap

  # awscli already presenet in ec2 instance
  # but installed after this bootstrap runs
  # so we must install it now
  pkg install -y awscli curl git-lite
  git clone https://github.com/freebsd/poudriere.git /root/poudriere
  cd /root/poudriere && ./configure && make && make install
  rehash
}

scale_down(){
  ## Turn autoscaling off
  # shellcheck disable=SC2086
  INSTANCE_ID=$(curl $CURL_FLAGS http://169.254.169.254/latest/meta-data/instance-id)
  # shellcheck disable=SC2086
  REGION=$(curl $CURL_FLAGS http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
  echo "[INFO] Scaling $INSTANCE_ID to 0"
  # shellcheck disable=SC2016
  AUTOSCALING_GROUP=$(aws ec2 describe-instances \
              --instance-id "${INSTANCE_ID}" \
              --region "${REGION}" \
              --query 'Reservations[].Instances[].[Tags[?Key==`aws:autoscaling:groupName`].Value]' \
              --output text)
  aws autoscaling set-desired-capacity --auto-scaling-group-name "${AUTOSCALING_GROUP}" --desired-capacity 0 --region "${REGION}"
  # Consider getting log off the instance
  # aws s3 cp "/var/log/bootstrap.log" "s3://${S3_BUCKET}/${DATE}/bootstrap-$(date +%s).log"
}

install_pkgs

# shellcheck disable=SC2086
if [ $AUTO_SPINDOWN -eq 1 ]; then
  trap scale_down EXIT
fi

# Key stuff
mkdir -p /usr/local/etc/ssl/keys
chmod 0600 /usr/local/etc/ssl/keys
touch "${SIGNING_KEY}"
chmod 0400 "${SIGNING_KEY}"
# Sync signing key
aws s3 cp "s3://${SIGNING_S3_KEY}" "${SIGNING_KEY}"

# TODO: Fix stopgap
mkdir /poudriere
mkdir /data

# Distfile cache
mkdir -p /usr/ports/distfiles

poudriere ports -c
# git clone into /poudriere/ports/robs-ports
mkdir /opt
git clone https://github.com/sarcasticadmin/ports.git /opt/robs-ports
poudriere ports -c -p robs-ports -m null -M /opt/robs-ports

poudriere jail -c -j "${ABI}" -v "${JAIL_VERSION}" -a "${ARCH}"

poudriere bulk -f /usr/local/etc/poudriere-list -j "${ABI}"

# Url will be hostname/pkgs/ABI
aws s3 sync "/data/packages/${ABI}-default/.latest/" "s3://${S3_BUCKET}/repos/${ABI}" --delete
aws s3 sync "/data/logs/bulk/${ABI}-default/latest/" "s3://${S3_BUCKET}/results/${ABI}" --delete
