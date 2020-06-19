data "aws_route53_zone" "selected" {
  name         = var.zone
  private_zone = true
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = var.domain
  type    = var.dtype
  ttl     = var.ttl
  records = var.resolv
}

variable "zone"    {}
variable "domain"  {}
variable "dtype"   {}
variable "ttl"     {}
variable "resolv"  {}

