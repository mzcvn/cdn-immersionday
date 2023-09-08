variable "bucket_name" {
  type = string
}

variable "region" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "stale_object_lambda_function_name" {
  type = string
}

variable "cw_logs_lambda_edge_retention" {
  type    = number
  default = 7
}

variable "test_stale_object" {
  type = bool
}