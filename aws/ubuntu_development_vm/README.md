<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | 3.45.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_instance.my-ec2-instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.my-internet-gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.my-route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_security_group_rule.sg-rule-mosh-inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.sg-rule-ssh-inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.my-subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.my-subnet-b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.my-subnet-c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.dev-vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ec2\_key\_pair | The EC2 key pair to use; must exist already in AWS EC2 | `string` | `"ssh-ed25519.pub"` | no |
| sg\_inbound\_ip | IP address (CIDR) to restrict ssh and mosh inbound traffic to. | `string` | `"0.0.0.0/0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| public\_ip | Public IP of the created instance. |
<!-- END_TF_DOCS -->
