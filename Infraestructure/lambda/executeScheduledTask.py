import os
import logging
import boto3
import uuid

DST_BUCKET = os.environ.get('DST_BUCKET')
REGION = os.environ.get('REGION')
s3 = boto3.resource('s3', region_name=REGION)

def lambda_handler(event, context):
    string = "dfghj"
    encoded_string = string.encode("utf-8")

    file_name = str(uuid.uuid4()) + '.txt'
    s3_path = file_name

    s3 = boto3.resource("s3")
    s3.Bucket(DST_BUCKET).put_object(Key=s3_path, Body=encoded_string)
    return {
        'statusCode': 200,
        'body': '{"status":"Bucket' + file_name + ' upload fine"}'
    }