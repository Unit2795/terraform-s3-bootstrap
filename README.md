# Store Terraform State in AWS

# About
A cheap alternative to storing remote state with Terraform Cloud or Terraform Enterprise. This example uses AWS S3 and DynamoDB to store the Terraform state remotely.

S3 stores the state file, Dynamo DB locks the state file to prevent concurrent writes.

This example uses CloudFormation, GitHub Actions, and a Shell script to create the remote state. Fold the example code into your Terraform project as needed to begin using remote state.

At the moment, it's necessary to provision the remote state before deploying with Terraform, unless you use a wrapper like Terragrunt. (Chicken and the egg type problem unfortunately. You need the remote state in order to deploy, but you need to deploy in order to create the remote state storage mechanisms)

Note!: Versioning is enabled on the S3 bucket. This can be a good practice to allow rolling back the state and to prevent accidental deletion of the state file, but it does increase the cost of the bucket.

# Usage
1. Configure the `state.config` file with your desired bucket name and DynamoDB table name. 
   1. If you want to use an extant bucket and table, the `/bootstrap` directory is not needed. Modify the "key" value so that it is unique in the bucket. This will prevent you from accidentally overwriting the terraform state of your other projects.
   2. Note, the bucket and table name MUST be unique in your AWS account if you intend to use the bootstrap script
2. Check the `main.tf` file to ensure the `terraform` and `aws` blocks are configured correctly. The `backend` block can stay as is, but you may also specify ["encrypt"](https://developer.hashicorp.com/terraform/language/backend/s3#encrypt) and other settings as you wish.
3. A GitHub action that runs the `boostrap.sh` script for you is provided in this repo. See [.github/workflows/terraform-apply.sh](./.github/workflows/terraform-apply.yml).
   1. You'll need to create an IAM identity provider and role with the necessary permissions to create the resources. Learn more about this here: [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) and here: [GitHub Actions setup](https://github.com/Unit2795/djoz-portfolio?tab=readme-ov-file#2-github-actions-setup).
   2. Create the `AWS_ACCOUNT_ID`, `AWS_DEFAULT_REGION`, and `AWS_IAM_ROLE_NAME` secrets in your GitHub repository.
   3. Set the `role-session-name` in the GitHub Actions workflow file to a unique value. It's not required, you can remove it if you wish. But it can be useful for debugging/auditing in CloudTrail logs.
   4. NOTE!: If you prefer not to use AWS OIDC, you can also use the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets. However, this is not recommended for production use. Using long-lived tokens like these is a security risk.
4. If you wish to run the boostrap script locally, you'll need to configure the [AWS CLI](https://aws.amazon.com/cli/) on your machine.
   1. Run the `bootstrap.sh` script in the `/bootstrap` directory to create the S3 bucket and DynamoDB table once you are ready
5. When you are finally ready to deploy using terraform, you'll need to specify the location of your backend configuration file. 
   1. You can do this by running `terraform init -backend-config=state.config`


# Important Files
- `main.tf` - The main Terraform configuration file, which configures the [backend](https://developer.hashicorp.com/terraform/language/backend/s3), [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs), and Terraform version.
- `state.config` - A configuration file that contains the bucket and table names. This file is used by the `bootstrap.sh` script AND the `main.tf` files.
- `/bootstrap`
  - `bootstrap-state.sh` - A shell script that creates the S3 bucket and DynamoDB table using CloudFormation, if they don't already exist.
  - `terraform-state.yaml` - A CloudFormation template that defines the S3 bucket and DynamoDB table resources.
- `.github/workflows/terraform-apply.yml` - A GitHub Actions workflow that runs the `bootstrap.sh` script.


# Resources
- https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- https://developer.hashicorp.com/terraform/tutorials/automation/github-actions
- https://medium.com/@thiagosalvatore/using-terraform-to-connect-github-actions-and-aws-with-oidc-0e3d27f00123