
################################################################################
# ACM Certificate & Validation
################################################################################

# 1. Create ACM Certificate in us-east-1 for both root and www domains.
resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = "makemydemo.xyz"
  subject_alternative_names = ["www.makemydemo.xyz"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Create DNS records in Route 53 to validate the certificate.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.custom_domain.zone_id
}

# 3. Wait for the certificate validation to complete.
resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# Route 53 DNS Zone
################################################################################

# 4. Create the main Hosted Zone for your domain.
resource "aws_route53_zone" "custom_domain" {
  name = "makemydemo.xyz"
}

################################################################################
# S3 Bucket (Private)
################################################################################

# 5. Create the S3 bucket to store website files.
resource "aws_s3_bucket" "bucket_s3" {
  bucket = var.s3_bucket_name
}

# 6. Block all public access to the S3 bucket.
resource "aws_s3_bucket_public_access_block" "bucket_s3_public_access" {
  bucket = aws_s3_bucket.bucket_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 7. Upload website files to the S3 bucket (no longer public).
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.bucket_s3.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "error_html" {
  bucket       = aws_s3_bucket.bucket_s3.id
  key          = "error.html"
  source       = "error.html"
  content_type = "text/html"
}

resource "aws_s3_object" "goku_jpeg" {
  bucket       = aws_s3_bucket.bucket_s3.id
  key          = "goku.jpeg"
  source       = "goku.jpeg"
  content_type = "image/jpeg"
}

################################################################################
# CloudFront CDN
################################################################################

# 8. Create a secure Origin Access Control (OAC) for CloudFront.
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "OAC for makemydemo.xyz"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 9. Create the CloudFront distribution.
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bucket_s3.bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for makemydemo.xyz"
  default_root_object = "index.html"

  aliases = ["makemydemo.xyz", "www.makemydemo.xyz"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # CRITICAL: Use the ARN from the *validation* resource.
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# 10. Create a secure bucket policy that ONLY allows access from our CloudFront distribution.
resource "aws_s3_bucket_policy" "bucket_s3_policy" {
  bucket = aws_s3_bucket.bucket_s3.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.bucket_s3.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

################################################################################
# Route 53 DNS Records
################################################################################

# 11. Create DNS 'A' record for the root domain (makemydemo.xyz)
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.custom_domain.zone_id
  name    = "makemydemo.xyz"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# 12. Create DNS 'A' record for the 'www' subdomain (www.makemydemo.xyz)
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.custom_domain.zone_id
  name    = "www.makemydemo.xyz"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
