# tf
Terraform files for small quick utility deployments.

### Azure
#### ubuntu_on_azure.tf
Deploys a single Ubuntu VM on Azure, with ssh login (port:80, public ip) open.
To restrict access to just the public IP (host) where you are running terraform from,
you can set the IP via:
```shell
	export TF_VAR_source_address_prefix=`curl 'https://api.ipify.org?format=text'
```

