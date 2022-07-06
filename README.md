# terraform-aws


Please export AWS secrets.(Which can be created/found in the AWS IAM Management Console) 
```
export aws_access_key_id = <Access Key ID>
export aws_secret_access_key = <Secret Access Key>
```

Run the following
```
terraform init
terraform plan
terraform apply
```

You will get an url output.

Use the following format to test if a site SSL Certs are still valid.
```
<url output>/ssl_check?url_id=<i.e. www.google.com>&
```

Expected Output
Good
```
SSL Certificate is still valid
```

Bad
```
Cert expired <Number> days ago
```
