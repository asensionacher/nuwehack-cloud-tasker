import logging
import boto3
import json
import os
import uuid
import re 
 
session = boto3.Session(region_name=os.environ['REGION'])
dynamodb_client = session.client('dynamodb')

cron_regex = '(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\d+(ns|us|µs|ms|s|m|h))+)|((((\d+,)+\d+|(\d+(\/|-)\d+)|\d+|\*) ?){5,7})'

def lambda_handler(event, context):
    try:
        print("event ->" + str(event))
        payload = json.loads(event["body"])
        print("payload ->" + str(payload))
        x = re.search(cron_regex, payload["cron_expression"])

        if x:
            print("Correct cron expression")
        else:
            return {
                'statusCode': 500,
                'body': '{"status":"cron_expression value is not a valid cron expression"}'
            }

        dynamodb_response = dynamodb_client.put_item(
            TableName=os.environ["TASK_TABLE"],
            Item={
                "task_name": {
                    "S": payload["task_name"]
                },
                "cron_expression": {
                    "S": payload["cron_expression"]
                },
                "task_id": {
                    "S": str(uuid.uuid4())
                }
            }
        )
        print(dynamodb_response)
        return {
            'statusCode': 201,
           'body': '{"status":"Task created"}'
        }
    except Exception as e:
        logging.error(e)
        return {
            'statusCode': 500,
           'body': '{"status":"Server error ' + e + '"}'
        }