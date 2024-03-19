# Lambda Python functions

## Abstract

In this folder will be stored all the necessary functions for the Lambdas deployed to work.

## createScheduledTask

### What it do

This function creates a registry in a DynamoDB which its table name is stored in the OS environment variable _TASK_TABLE_ with the parameters _task_name_, _cron_expression_, _task_id_. All the values except _task_id_ are received throught the _payload_ and the _task_id_ value is randomnly generated using _uuid_ module. If the _cron_expression_ parameter is not a valid cron expression, it will return an error.

### Input

JSON payload following this structure:

``` JSON
{
    "task_name": string,
    "cron_expression": string
}
```

example:

``` JSON
{
    "task_name": "myAwesomeTask",
    "cron_expression": "* * * * *"
}
```

### Response

If it is succesfull, the response will be _201_ code with a JSON body following this structure:

```JSON
{
    "status":"Task created"
}
```

If it is not succesfull, the response will be _500_ code with a JSON body following this structure:

```JSON
{
    "status":"Server error: (ERROR_FROM_PYTHON)"
}
```

If the _cron_expression_ is not a valid CRON expression:

```JSON
{
    "status":
    "cron_expression value is not a valid cron expression"
}
```

## listScheduledTask

### What it do

This function lists all the registries in a DynamoDB which its table name is stored in the OS environment variable _TASK_TABLE_.

### Input

NO input needed

### Response

If it is succesfull, the response will be _201_ code with a JSON body following this structure:

```JSON
{
    [
        {
            "task_name": "a",
            "cron_expression": "* * * * *",
            "task_id": "ca7e0d47-1354-445b-b91f-77d574f22d59"
        },
        {
            "task_name": "b",
            "cron_expression": "* * * * *",
            "task_id": "804a5322-3e2b-48af-acc3-fdb2c5a26c61"
        },
        {
            "task_name": "e",
            "cron_expression": "* * * * *",
            "task_id": "fa8d1a22-f2f2-49c6-8ad8-536b315bb612"
        },
        {
            "task_name": "a",
            "cron_expression": "* * * * *",
            "task_id": "b632e4d4-4713-4eb8-bcad-3ea7e3241570"
        },
        {
            "task_name": "c",
            "cron_expression": "* * * * *",
            "task_id": "6d7b8178-f93e-4f2e-bb9a-bf423f577825"
        },
        {
            "task_name": "d",
            "cron_expression": "* * * * *",
            "task_id": "96c87e62-9546-4a9b-a5d9-d541d1d2b4cb"
        },
        {
            "task_name": "f",
            "cron_expression": "* * * * *",
            "task_id": "eeff059b-8678-4bda-9b95-2b957652466f"
        },
        {
            "task_name": "a",
            "cron_expression": "* * * * *",
            "task_id": "33309f3f-95b3-4a1b-871e-8cbea8241dee"
        }
    ]
}
```

If it is not succesfull, the response will be _500_ code with a JSON body following this structure:

```JSON
{
    "status":"Server error: (ERROR_FROM_PYTHON)"
}
```

## executeScheduledTask

### What it do

This function uploads a file in a S3 bucket where the name is stored in the OS environment variable _DST_BUCKET_.

### Input

Not needed.

### Response

If it is succesfull, the response will be _201_ code with a JSON body following this structure:

```JSON
{
    "status":"Bucket' + file_name + ' upload fine"
}
```

If it is not succesfull, the response will be _500_ code with a JSON body following this structure:

```JSON
{
    "status":"Server error: (ERROR_FROM_PYTHON)"
}
```