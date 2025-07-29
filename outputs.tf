output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bucket_s3.bucket
}

output "s3_website_endpoint" {
  description = "The S3 static website hosting endpoint"
  value       = aws_s3_bucket.bucket_s3.bucket_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_url" {
  description = "URL of the website served through CloudFront"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}


output "acm_certificate_arn" {
  value       = aws_acm_certificate.cert.arn
  description = "ARN of ACM Certificate for CloudFront"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "CloudFront distribution domain name"
}

output "route53_name_servers" {
  description = "The nameservers for the Route53 hosted zone"
  value       = aws_route53_zone.custom_domain.name_servers
}
