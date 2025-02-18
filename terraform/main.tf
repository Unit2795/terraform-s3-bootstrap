terraform {
	backend "s3" {
		bucket = ""
		key    = ""
		dynamodb_table = ""
		region = ""
	}

	required_providers {
		aws = {
			source  = "hashicorp/aws"
			# Adjust AWS provider version as needed
			version = "~> 5.84.0"
		}
	}

	# Adjust terraform version as needed
	required_version = ">= 1.2.0"
}

# Configure the default AWS provider
provider "aws" {
	region = var.aws_region

	skip_metadata_api_check     = true
	skip_region_validation     = true
	skip_credentials_validation = true
}