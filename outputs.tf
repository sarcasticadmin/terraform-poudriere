output "poudriere_url" {
  value = "http://${var.pkg_s3_bucket}/results/FreeBSD:${element(split(".", var.jail_version),0)}:amd64/build.html"
}
