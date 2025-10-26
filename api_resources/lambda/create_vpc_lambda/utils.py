import json
import boto3
import os
from botocore.exceptions import ClientError

## Setting up DynamoDB client
ddb_client = boto3.client("dynamodb")

vpc_ddb_table = os.getenv('vpc_info') # DynamoDB storing vpc information

class Utils:
    """
    Class stores the common utility function that the lambda can use
    """
    @staticmethod
    def check_overlapping_cidr(cidr_range: str,aws_region: str,aws_account: int) -> str:
        """
        Function to check if we have already provisioned a VPC in target account and region with overlapping CIDR
        Args:
           cidr_range (str) : CIDR range to the VPC to be verified
           aws_region (str) : AWS region where verification has to be done
           aws_account (str) : AWS account where verification has to be done
        Returns:
           bool : Indicating whether we have overlapping CIDR or not
        """    
        response = ddb_client.query(
            TableName=vpc_ddb_table,
            IndexName='VPC_GSI',
            KeyConditionExpression="aws_region = :region",
            ExpressionAttributeValues={":region": {"S": aws_region}},
            FilterExpression="aws_account = :aws_account",
            ExpressionAttributeValues={":region": {"S": aws_region}, ":a": {"S": aws_account}}

        )
        ## Looping through results to verify overlapping CIDRs
        for item in response.get("Items", []):
            existing_cidr = item["vpc_cidr"]["S"]
            if cidr_range == existing_cidr:
                return True
        return False    

    @staticmethod    
    def format_response(status_code: int, response_dict: dict) -> dict:
        """
        Function to format response message returned to APIGW from lambda
        """
        return {
            "statusCode": status_code,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(response_dict)
    }

    @staticmethod
    def assume_role_target_account(target_account:str):
        """
        Function to enable vpc create role in target account
        """
        sts_client = boto3.client('sts')
        target_role_arn = f'arn:aws:iam::{target_account}:role/service-role/create-vpc-role'
        try:
            assume_role_response = sts_client.assume_role(
                RoleArn=target_role_arn,
                RoleSessionName='create_vpc'
            )
            target_account_credentials = assume_role_response['Credentials']
            return boto3.Session(
                aws_access_key_id=target_account_credentials["AccessKeyId"],
                aws_secret_access_key=target_account_credentials["SecretAccessKey"],
                aws_session_token=target_account_credentials["SessionToken"],
            )
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code == "NoSuchEntity":
                raise Exception(f"Role {target_role_arn} does not seem to exist in target account {target_account}")
            elif error_code == "AccessDenied":
                raise Exception(f"Lambda is not authorized to assume role {target_role_arn}")

    @staticmethod
    def update_ddb_status(vpc_id=None,request_id=None,status=None,subnet_ids=None,cidr_block=None,account=None,region=None,reason=None):
        """
        Function to update processing status in DynamoDB table
        """
        if status == 'success':
            update_expression = "SET #st = :st, #re = :re, #vpc = :vpc, #subet = :subnet"
            expr_update_names = {"#st": "status", "#re": "reason", "#vpc": "vpc_id", "#subet": "subnet_ids"}
            expr_update_values = {":st": {"S": status},":re": {"S": reason},":vpc": {"S": vpc_id},":subnet": {"SS": subnet_ids}}
        elif status == 'error':
            update_expression = "SET #st = :st, #re = :re"
            expr_update_names = {"#st": "status", "#re": "reason"}
            expr_update_values = {":st": {"S": status},":re": {"S": reason}}
        else:
            update_expression = "SET #st = :st"    
            expr_update_names = {"#st": "status"}
            expr_update_values = {":st": {"S": status}}
        ddb_update_response = ddb_client.update_item(
            TableName=vpc_ddb_table,
            Key={'request_id': {'S': request_id}},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expr_update_names,
            ExpressionAttributeValues=expr_update_values,
            ReturnValues="UPDATED_NEW"
        )

