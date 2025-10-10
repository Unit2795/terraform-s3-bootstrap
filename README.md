# Store Terraform State in AWS

## About

This boilerplate code helps you **set up a remote state backend for Terraform** using **AWS S3**. You can easily integrate this boilerplate into your own Terraform projects. The code in this repo includes:

- **Example Terraform configuration:** a ready-to-use `main.tf` file showing how to define and initialize a remote S3 backend for Terraform.
- **`state.config` Backend Config File:** a reusable configuration file that cleanly stores the information for your remote state settings
- **Convenience shell scripts:** a small toolkit for creating, deleting, and unlocking your Terraform remote state resources via CloudFormation and AWS CLI.
- **CloudFormation template:** an infrastructure-as-code blueprint that provisions a secure, versioned, and encrypted S3 bucket using AWS CloudFormation.
- **Sample GitHub Actions workflows:** CI/CD examples that automatically run the shell scripts to bootstrap, apply, and destroy Terraform infrastructure, using AWS OpenID Connect (OIDC) for secure, keyless authentication.

Storing Terraform state in a remote backend is a best practice for collaboration. Storing it in AWS S3 provides a cost-effective alternative to Terraform Cloud or Terraform Enterprise. While the developer experience isn’t as polished as Terraform Cloud, it’s **cheap, flexible, and reliable**. With the help of the included **shell scripts and GitHub Actions**; this can be set up, managed, and destroyed with a single command or automatically in CI/CD.

> ℹ️Note: Since Terraform version 1.10, DynamoDB state locking has become deprecated with the introduction of conditional writes to AWS S3. You no longer need DynamoDB. If you're using an older version of Terraform, see the [archive/dynamo-db](https://github.com/Unit2795/terraform-s3-bootstrap/tree/archive/dynamo-db) branch, which contains code for state locking with S3 and DynamoDB. Please note that this branch is not being updated.

## Key Components

- **S3** stores both the Terraform state file and the lock file.
- **CloudFormation** provisions the S3 bucket automatically.
- **Shell scripts** handle deploying and deleting the CloudFormation stack, as well as unlocking Terraform state by removing the lock file when necessary.
- **GitHub Actions** demonstrate how these processes fit into a CI/CD pipeline with Terraform.

> ℹ️**Note**: At the moment, it's necessary to provision the remote state before deploying with Terraform, unless you use a wrapper like Terragrunt. This creates a "chicken-and-egg" type problem. Terraform needs remote state to deploy, but you need to deploy in order to create the remote state storage resources.

> 🔐**Security**: S3 versioning and encryption are enabled by default. These features help you roll back to previous states and protect your state file, but they may slightly increase storage costs.

## Usage

1. **Configure `state.config`**
   1. Set your desired **bucket name**, **AWS region**, and **Terraform state file** name (key).
   2. You may use an extant S3 bucket in your AWS account, just make sure the key for your state file is unique in the bucket. If you do this, the `bootstrap-state.sh` and `delete-stack.sh` files are not needed, since your bucket is managed outside of CloudFormation.
   3. Note, the bucket name **MUST be unique** in your AWS account if you intend to use the bootstrap script, since CloudFormation will create a new bucket.
2. **Check Terraform Configuration**
   1. Review `main.tf` to ensure the `terraform` and `aws` blocks are configured correctly.
   2. The `backend` block can stay as is, it will be populated by the `state.config` file. You may also specify the ["encrypt"](https://developer.hashicorp.com/terraform/language/backend/s3#encrypt) option and other settings if desired.
3. **GitHub Action Setup**
   1. An example GitHub Action that runs the `boostrap-state.sh` script for you is provided in this repo. See [.github/workflows/terraform-apply.sh](./.github/workflows/terraform-apply.yml).
   2. Create an IAM identity provider and role with the necessary permissions to create the resources. Learn more about this here:
      1. [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
      2. [GitHub Actions setup](https://github.com/Unit2795/djoz-portfolio?tab=readme-ov-file#2-github-actions-setup)
   3. Add the following repository secrets in your GitHub repo:
      1. `AWS_ACCOUNT_ID`
      2. `AWS_DEFAULT_REGION`
      3. `AWS_IAM_ROLE_NAME`
   4. Set a unique `role-session-name` in the GitHub Actions workflow file. This is optional but useful for debugging/auditing in **CloudTrail** logs.
   5. > Alternative: If you prefer not to use AWS OIDC, you can use the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets. This is not recommended for production use due to the security risks of long-lived credentials.
4. **Running Locally**
   1. If you wish to run the boostrap script locally, you'll need to configure the [AWS CLI](https://aws.amazon.com/cli/) on your machine.
   2. Run `bootstrap-state.sh` to create the S3 bucket.
   3. **Deploying with Terraform**
      1. When ready to deploy, initialize Terraform with your backend configuration: `terraform init -backend-config=state.config`

## Important Files

| Path                                      | Description                                                                                                                                                                                                                           |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `main.tf`                                 | Main Terraform configuration file. Defines the [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3), [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs), and Terraform version. |
| `state.config`                            | Contains S3 bucket and state file configuration for Terraform. Also used by the shell scripts                                                                                                                                         |
| `/bootstrap/bootstrap-state.sh`           | Creates the S3 bucket via CloudFormation (if it doesn’t already exist).                                                                                                                                                               |
| `/bootstrap/terraform-state.yaml`         | CloudFormation template defining the S3 bucket resources.                                                                                                                                                                             |
| `/bootstrap/delete-stack.sh`              | Deletes the CloudFormation stack and its resources (including the S3 bucket). Use with caution.                                                                                                                                       |
| `/bootstrap/forcefully-unlock.sh`         | Forcefully unlocks Terraform state by deleting the lock file, useful after interrupted Terraform runs.                                                                                                                                |
| `.github/workflows/terraform-apply.yml`   | GitHub Actions workflow that runs `bootstrap-state.sh`.                                                                                                                                                                               |
| `.github/workflows/terraform-destroy.yml` | GitHub Actions workflow that runs `terraform destroy` and executes `delete-stack.sh` to remove the S3 bucket.                                                                                                                         |

## Important Note

In `/terraform/bootstrap/terraform-state.yaml`, the S3 bucket is configured with a `DeletionPolicy` of `Delete`.
This means deleting the CloudFormation stack will **permanently remove the S3 bucket and all state file versions**.

To retain your state after stack deletion, change the policy to:

```yaml
DeletionPolicy: Retain
```

## Why CloudFormation?

You might wonder why this setup uses CloudFormation instead of Terraform to provision the remote state resources. This setup does require familiarity with both Terraform and CloudFormation. Luckily, the CloudFormation template used in this repo is very simple.

**The main reason is that CloudFormation manages its own state internally**, eliminating the circular dependency problem that would occur if Terraform tried to manage its own backend before the backend existed. If we attempted to use Terraform to create the S3 bucket, Terraform would need state storage configured to store that very state.

CloudFormation doesn’t require a separate state store because it tracks resource states natively within AWS.

It's not ideal, if you want to sidestep these concerns entirely, I recommend a wrapper like [Terragrunt](https://terragrunt.gruntwork.io/)

## Resources

- [Configuring OpenID Connect in Amazon Web Services (docs.github.com)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Automate Terraform with GitHub Actions (developer.hashicorp.com)](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Using Terraform to connect GitHub Actions and AWS with OIDC (medium.com @thiagosalvatore)](https://medium.com/@thiagosalvatore/using-terraform-to-connect-github-actions-and-aws-with-oidc-0e3d27f00123)
- [DynamoDB not needed for Terraform State locking in S3 anymore (medium.com @aws-specialists)](https://medium.com/aws-specialists/dynamodb-not-needed-for-terraform-state-locking-in-s3-anymore-29a8054fc0e9)
- [S3 Backend Terraform Documentation (developer.hashicorp.com)](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- [See an example of this code in used in production here (github.com)](https://github.com/Unit2795/djoz-portfolio)
