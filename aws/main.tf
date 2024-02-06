
data "aws_caller_identity" "current" {}


resource "aws_s3_bucket" "this" {
  bucket = "${data.aws_caller_identity.current.account_id}-mtls-test-bucket"
}

resource "aws_s3_bucket_policy" "lb_to_s3" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.lb_to_s3.json
}

data "aws_iam_policy_document" "lb_to_s3" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["582318560864"]
    }

    actions = [
    "s3:PutObject"]

    resources = [
      "${aws_s3_bucket.this.arn}/mtls-test-lb-access/*",
      "${aws_s3_bucket.this.arn}/mtls-test-lb-connection/*",
    ]
  }
}

resource "aws_s3_object" "ca_cert" {
  bucket = aws_s3_bucket.this.bucket
  key    = "ca.crt"
  source = "../ca.crt"

}

resource "aws_lb_trust_store" "this" {
  name = "tf-example-lb-ts"

  ca_certificates_bundle_s3_bucket = aws_s3_bucket.this.bucket
  ca_certificates_bundle_s3_key    = "ca.crt"

  depends_on = [aws_s3_object.ca_cert]


}

resource "aws_lb_target_group" "this" {
  name        = "mtls-lb-target"
  target_type = "lambda"
}

resource "aws_acm_certificate" "this" {
  domain_name       = "mtls-test.${data.aws_route53_zone.this.name}"
  validation_method = "DNS"
}

data "aws_route53_zone" "this" {
  name = var.route53_zone_name
}
resource "aws_route53_record" "certificate" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_route53_record" "lb" {
  allow_overwrite = true
  name            = "mtls-test"
  type            = "A"
  zone_id         = data.aws_route53_zone.this.zone_id
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.id
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.this.arn

  default_action {
    target_group_arn = aws_lb_target_group.this.id
    type             = "forward"
  }

  mutual_authentication {
    mode            = "verify"
    trust_store_arn = aws_lb_trust_store.this.arn
  }
  depends_on = [aws_route53_record.certificate]
}


resource "aws_security_group" "lb" {
  name   = "mtls_lb"
  vpc_id = aws_vpc.this.id
}
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_egress_rule" "lb" {
  security_group_id = aws_security_group.lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_lb" "this" {
  name               = "mtls-test-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  security_groups    = [aws_security_group.lb.id]

  access_logs {
    bucket  = aws_s3_bucket.this.id
    prefix  = "mtls-test-lb-access"
    enabled = true
  }

  connection_logs {
    bucket  = aws_s3_bucket.this.id
    prefix  = "mtls-test-lb-connection"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.lb_to_s3]
}
