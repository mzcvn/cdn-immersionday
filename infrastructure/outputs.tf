output "cloudfront_distribution_name_s3_origin" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_distribution_name_api_gateway_origin" {
  value = aws_cloudfront_distribution.api_gateway.domain_name
}