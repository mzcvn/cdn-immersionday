# Leveraging the Power of CloudFront and Edge Computing

This repository demonstrates 02 scenarios:
- Image optimization with CloudFront Function and Lambda@Edge
- Stale-while-revalidate and stale-if-error cache control directives

![Image optimization](image_optimization.png)
<div align="center">Figure 1. Image optimization </div>
</br></br>

<div align="center">
  <img src="/cache_control_directives.png">
</div>
<div align="center">Figure 2. Cache control directives</div>

# Usage
## Prerequiste
- Ensure you have Terraform version >= 1.45
- Ensure you have NodeJS version 16.x
- Ensure you have already created a S3 Bucket and a DynamoDB Table for Terraform backend
## Get Started
### Install node package for lambda edge function, from root directory, run:
`cd lambda`
#### For MacOS:
`npm install --platform=linux --arch=x64 sharp`
#### For Linux and Windows:
`npm install`
### Provision infrastructure, from root directory, run:
`cd infrastructure`

<p>Edit version.tf file ensure fields bucket and dynamodb_table is upated with your S3 Bucket and DynamoDB Table</p>

`terraform init`
`terraform apply`

### For update function code
Repeat the step above, except for cloudfront function and lambda stale object, skip the install package step.

