data "aws_iam_policy_document" "allow_access_from_cloudfront" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
      "arn:aws:s3:::${var.bucket_name}"
    ]
    condition {
        test        = "StringEquals"
        variable    = "AWS:SourceArn"
        values      = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

data "aws_iam_policy_document" "lambda_edge_permission" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:logs:*:*:*"
    ]
  }
}

data "aws_iam_policy_document" "lambda_edge_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "edgelambda.amazonaws.com"
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_policy" "lamda_edge_policy" {
  name = "lambda-edge-policy"
  description = "IAM policy for Lambda Edge to work with S3 bucket"
  policy = data.aws_iam_policy_document.lambda_edge_permission.json
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  role = aws_iam_role.lambda_edge_role.name
  policy_arn = aws_iam_policy.lamda_edge_policy.arn
}

resource "aws_iam_role" "lambda_edge_role" {
  name = "lambda_edge_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_edge_assume_role.json
}

##-------------------------------------##
##------------ S3 Origin -------------###
##-----------------------------------###

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}
resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cloud_front" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.allow_access_from_cloudfront.json
}

//Configure CORS rules

resource "aws_s3_bucket_cors_configuration" "cors_rules" {
  bucket = aws_s3_bucket.this.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

##--------------------------------------------##
##-----General CloudFront Configuration -----###
##-------------------------------------------###

//Define CloudFront function
resource "aws_cloudfront_function" "img_optimization_function" {
  name      = "image_optimization"
  runtime   = "cloudfront-js-1.0"
  publish   = true
  code      = file("../cf_function/img_optimization.js")
}

//Define CloudFront Cache Policy
resource "aws_cloudfront_cache_policy" "custom_cache" {
    name    = "custom_cache"
    comment = "cache policy to forward all query strings to origin"
    default_ttl = 86400
    max_ttl = 31536000
    min_ttl = 1

    parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"

    }
  } 
}

##--------------------------------------------##
##------------ Lambda Function  -------------###
##-------------------------------------------###
data "archive_file" "lambda" {
  type        = "zip"
  source_dir = "../lambda/"
  output_path = "../function.zip"
}

resource "aws_lambda_function" "lambda_edge" {
  provider = aws.lambda_edge
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_edge_role.arn
  filename         = "../function.zip"
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  memory_size      = 1024
  ephemeral_storage {
    size           = 512
  }
  timeout          = 30
  publish          = true
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.cw_logs_lambda_edge_retention
}

##------------------------------------####
##### CloudFront Distribution (Prod) #####
##------------------------------------####
locals {
    s3_origin_id = "cdn-s3-origin"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = local.s3_origin_id
  description                       = "This is Origin Access Control for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    enabled             = true
    # retain_on_delete    = true

    origin {
        domain_name               = aws_s3_bucket.this.bucket_regional_domain_name
        origin_access_control_id  = aws_cloudfront_origin_access_control.this.id
        origin_id                 = local.s3_origin_id
    }
    custom_error_response {
        error_caching_min_ttl = 10
        error_code            = 403
        response_code         = 403
        response_page_path    = "/index.html"
    }
    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        cache_policy_id  = aws_cloudfront_cache_policy.custom_cache.id

        viewer_protocol_policy = "allow-all"
        min_ttl                = 0
        default_ttl            = 0
        max_ttl                = 0

        lambda_function_association {
          event_type = "origin-request"
          lambda_arn = aws_lambda_function.lambda_edge.qualified_arn
          include_body = true
        }

        function_association {
          event_type = "viewer-request"
          function_arn = aws_cloudfront_function.img_optimization_function.arn
        }
    }
    
    price_class = "PriceClass_200"

    restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }

    tags = {
        Environment = "production"
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
    lifecycle {
        create_before_destroy = true
    }
}

##-------------------------------------##
##------------ Stale Object -------------###
##-----------------------------------###

data "archive_file" "lambda_stale_object" {
  type        = "zip"
  source_dir = "../lambda_stale_object"
  output_path = "../stale_object.zip"
}

resource "aws_lambda_function" "lambda_stale_object" {
  function_name    = "lambda_stale_object"
  role             = aws_iam_role.lambda_stale_object_role.arn
  filename         = "../stale_object.zip"
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  source_code_hash = data.archive_file.lambda_stale_object.output_base64sha256

  memory_size      = 1024
  ephemeral_storage {
    size           = 512
  }
  timeout          = 30
  publish          = true

  environment {
    variables = {
      StatusCode = 200
    }
  }
}


data "aws_iam_policy_document" "lambda_stale_object_permission" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

data "aws_iam_policy_document" "lambda_stale_object_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "lamda_stale_object_policy" {
  name        = "lambda-stale-object-policy"
  description = "IAM policy for Lambda Edge to work with S3 bucket"
  policy      = data.aws_iam_policy_document.lambda_stale_object_permission.json
}

resource "aws_iam_role_policy_attachment" "iam_role_stale_object_policy_attachment" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = aws_iam_policy.lamda_stale_object_policy.arn
}

resource "aws_iam_role" "lambda_stale_object_role" {
  name               = "lambda-stale-object-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_stale_object_assume_role.json
}

resource "aws_apigatewayv2_api" "lambda_stale_object" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stale_object" {
  api_id = aws_apigatewayv2_api.lambda_stale_object.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "get_stale_object" {
  api_id = aws_apigatewayv2_api.lambda_stale_object.id

  integration_uri    = aws_lambda_function.lambda_stale_object.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_stale_object" {
  api_id = aws_apigatewayv2_api.lambda_stale_object.id

  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.get_stale_object.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda_stale_object.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_stale_object.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda_stale_object.execution_arn}/*/*"
}

resource "aws_cloudfront_cache_policy" "get_stale_object" {
    name    = "get_stale_object"
    comment = "cache policy to forward all query strings to origin"
    default_ttl = 86400
    max_ttl = 31536000
    min_ttl = 1

    parameters_in_cache_key_and_forwarded_to_origin {
      cookies_config {
        cookie_behavior = "none"
      }
      headers_config {
        header_behavior = "none"
      }
      query_strings_config {
        query_string_behavior = "none"
      }
      enable_accept_encoding_brotli = false
      enable_accept_encoding_gzip   = false
  } 
}

resource "aws_cloudfront_distribution" "api_gateway" {
    enabled             = true
    # retain_on_delete    = true

    origin {
      domain_name               = trim("${aws_apigatewayv2_api.lambda_stale_object.api_endpoint}", "https://")
      origin_path               = "/prod"
      origin_id                 = "get-stale-object"
      
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }


    custom_error_response {
        error_caching_min_ttl = 10
        error_code            = 403
        response_code         = 403
        response_page_path    = "/index.html"
    }
    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "get-stale-object"
        cache_policy_id  = aws_cloudfront_cache_policy.get_stale_object.id

        viewer_protocol_policy = "allow-all"
        min_ttl                = 0
        default_ttl            = 5
        max_ttl                = 0
    }
    
    price_class = "PriceClass_200"

    restrictions {
        geo_restriction {
          restriction_type = "none"
        }
    }

    tags = {
        Environment = "production"
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
    lifecycle {
        create_before_destroy = true
    }
}
