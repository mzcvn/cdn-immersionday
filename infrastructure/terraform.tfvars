// origin S3 bucket
bucket_name = "cdn-s3-origin"

//Name of lambda@edge function (in region us-east-1) to handle image optimization
lambda_function_name = "image_optimization"

//Name of lambda function to set cache control
stale_object_lambda_function_name = "stale_object"

//Region to deploy AWS resources
region = "ap-southeast-1"

//Specify cache policy in default behavior in origin API Gateway to test scale object or test persistent connections.
// True: to test stale object OR False: to test persistent connections.
test_stale_object = false