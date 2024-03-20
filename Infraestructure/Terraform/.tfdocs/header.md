# nuwehack-cloud-tasker Terraform deployment

![LocalStack](https://img.shields.io/static/v1?label=Works&message=@LocalStack&color=purple&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAKgAAACoABZrFArwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAALbSURBVHic7ZpNaxNRFIafczNTGIq0G2M7pXWRlRv3Lusf8AMFEQT3guDWhX9BcC/uFAr1B4igLgSF4EYDtsuQ3M5GYrTaj3Tmui2SpMnM3PlK3m1uzjnPw8xw50MoaNrttl+r1e4CNRv1jTG/+v3+c8dG8TSilHoAPLZVX0RYWlraUbYaJI2IuLZ7KKUWCisgq8wF5D1A3rF+EQyCYPHo6Ghh3BrP8wb1en3f9izDYlVAp9O5EkXRB8dxxl7QBoNBpLW+7fv+a5vzDIvVU0BELhpjJrmaK2NMw+YsIxunUaTZbLrdbveZ1vpmGvWyTOJToNlsuqurq1vAdWPMeSDzwzhJEh0Bp+FTmifzxBZQBXiIKaAq8BBDQJXgYUoBVYOHKQRUER4mFFBVeJhAQJXh4QwBVYeHMQJmAR5GCJgVeBgiYJbg4T8BswYPp+4GW63WwvLy8hZwLcd5TudvBj3+OFBIeA4PD596nvc1iiIrD21qtdr+ysrKR8cY42itCwUP0Gg0+sC27T5qb2/vMunB/0ipTmZxfN//orW+BCwmrGV6vd63BP9P2j9WxGbxbrd7B3g14fLfwFsROUlzBmNM33XdR6Meuxfp5eg54IYxJvXCx8fHL4F3w36blTdDI4/0WREwMnMBeQ+Qd+YC8h4g78wF5D1A3rEqwBiT6q4ubpRSI+ewuhP0PO/NwcHBExHJZZ8PICI/e73ep7z6zzNPwWP1djhuOp3OfRG5kLROFEXv19fXP49bU6TbYQDa7XZDRF6kUUtEtoFb49YUbh/gOM7YbwqnyG4URQ/PWlQ4ASllNwzDzY2NDX3WwioKmBgeqidgKnioloCp4aE6AmLBQzUExIaH8gtIBA/lFrCTFB7KK2AnDMOrSeGhnAJSg4fyCUgVHsolIHV4KI8AK/BQDgHW4KH4AqzCQwEfiIRheKKUAvjuuu7m2tpakPdMmcYYI1rre0EQ1LPo9w82qyNziMdZ3AAAAABJRU5ErkJggg==) ![Python](https://img.shields.io/badge/Python-FFD43B?style=for-the-badge&logo=python&logoColor=blue) ![AWS](https://img.shields.io/badge/Amazon_AWS-FF9900?style=for-the-badge&logo=amazonaws&)

[![Deploy infrastructure on LocalStack](https://github.com/asensionacher/nuwehack-cloud-tasker/actions/workflows/localstacks.yml/badge.svg)](https://github.com/asensionacher/nuwehack-cloud-tasker/actions/workflows/localstacks.yml)

## Description

This repository deploys the Amazon Web Services resources for passing the `nuwehack-cloud-tasker` challenge. The resources deployed follows this architecture:

![architecture.png](.tfdocs/architecture.png)

Where the user can call to the endpoints on the API Gateway for adding a record to the DynamoDB or getting all the records from the DynamoDB that are redirected to the Lambdas and also there is a timer where each minute the EventBridge sends a API Call to the API Gateway which redirects to a Lambda that creates a random file in a S3 bucket.

> [!WARNING]  
> A WAFv2 was intended to add to this architecture. However, _localstacks_ is not accepting this feature
> in the community version.

## How to use

This code is intended to be used with LocalStacks, is not tested with a real AWS environment.

For testing, install in your machine `docker`, `docker-compose`, `localstacks`, `terraform`, `jq`. 

For getting up the `localstacks` environment, navigate to the root of this directory and execute in a shell:

```sh
docker-compose up
``` 
Then, open another shell, navigate to the folder `Infraestructure/Terraform` and execute the following:

```sh
terraform init
terraform plan
terraform apply --auto-approve 
terraform output --json > out.json
```

Once it is finished, all the resources will be deployed in `localstacks`. For testing the endpoints, do the following:

- /createtask

``` sh
api_rest_api_id=$(cat out.json | jq -r '.api_rest_api_id.value')
curl -X POST "http://localhost:4566/restapis/${api_rest_api_id}/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "MyAwesomeTask",
  "cron_expression": "* * * * *"
}'
```

The response should be the following:

```JSON
{
    "status":"Task created"
}
```

- /listtask

``` sh
api_rest_api_id=$(cat out.json | jq -r '.api_rest_api_id.value')
curl -X GET "http://localhost:4566/restapis/${api_rest_api_id}/prod/_user_request_/listtask"
```

The response should be the following, where the `task_id` would be a random UUID:
```JSON
[
    {
        "task_name": "MyAwesomeTask", 
        "cron_expression": "* * * * *", 
        "task_id": "b43d22dc-841a-4207-b458-b391297f2c3c"
    }
]
```

- /every-minute

This endpoint must not be used by a user, but the EventBridge do. While we were testing the other endpoints, files in the S3 bucket were created. For listing the files, execute the following:

```sh
awslocal s3 ls s3://taskstorage
```

The response should be something like this:

```txt
2024-03-19 10:53:43          5 0031a2f9-c72a-4e3e-9507-cd2c9b3c0dcb.txt
2024-03-19 10:54:37          5 03802358-21b8-4995-b866-fba84857f8b0.txt
2024-03-19 10:55:42          5 076c4bf9-f1cf-4c80-a145-7fd022e4747d.txt
2024-03-19 10:56:38          5 07849be3-92a4-46c8-930f-b15de0bb20fd.txt
2024-03-19 10:57:41          5 0acbf906-4a2f-4a4f-9089-c719a6f603a7.txt
```
