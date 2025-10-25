import boto3
import json
import os
from boto3.dynamodb.conditions import Key
import logging

# Create DynamoDB resource for table holding VPC info records
ddb_client = boto3.client('dynamodb')
vpc_ddb_table = os.getenv('vpc_info')


# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to fetch details of VPC id from DDB table
    Args:
        tracking_id (str) : tracking id of the VPC provisioning request
    Returns:
        json : json containing details of the VPC
    Error response:
        404 Not found : If tracking id does not exist
        500 Internal server : Any other error
    """
    try:
        tracking_id = event['queryStringParameters'].get('tracking_id')
        logger.info(f'Querying DynamoDB to fetch details for request id {tracking_id}')
        ddb_response = ddb_client.get_item(Key={'tracking_id': {'S': tracking_id}},TableName=vpc_ddb_table).get('Item')
        if ddb_response:      
            logger.info(f'Record of the request ID {tracking_id} found')
            vpc_status  = ddb_response['status']['S']
            if vpc_status == 'pending':
                logger.info(f'VPC against {tracking_id} is yet to be provisioned')
                return format_response(202,{'message': f'VPC for request id {tracking_id} is not yet provisioned'})
            elif vpc_status == 'error':
                logger.error(f'VPC against {tracking_id} was not provisioned due to {vpc_status}')
                return format_response(500,{'message': vpc_status})
            else:
                response = {
                    "vpc_id": ddb_response['vpc_id']['S'],
                    "cidr_block": ddb_response['cidr_range']['S'],
                    "subnet_ids": list(ddb_response['subnet_ids']['SS']),
                    "region": ddb_response['aws_region']['S']
                }
                return format_response(200, response)
        else:
            logger.error(f'Record of the request ID {tracking_id} could not be found')
            return format_response(404, {{'message': f'Tracking id {tracking_id} seems to be invalid. Please check and provide a valid id.'}})
            
    except Exception as e:
        logger.exception(e)
        return format_response(500, {'message': 'An error occured, please try again'})


def format_response(status_code: int, response_dict: dict) -> dict:
    """
    Function to format response message returned to APIGW from lambda
    """
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(response_dict)
    }