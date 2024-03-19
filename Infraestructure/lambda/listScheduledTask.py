import logging
import boto3
import json
import os
 
dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])

def lambda_handler(event, context):
    try:
        table_name=os.environ["TASK_TABLE"]
        table = dynamodb.Table(table_name)
        response = table.scan()
        data = response['Items']
        return {
            'statusCode': 201,
            'body': json.dumps(data)
        }
    except Exception as e:
        logging.error(e)
        return {
            'statusCode': 500,
           'body': '{"status":"Server error ' + e + '"}'
        }