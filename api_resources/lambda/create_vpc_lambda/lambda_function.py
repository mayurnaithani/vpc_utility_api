import boto3
import json
import os
import logging
from datetime import datetime
from vpc_exception import VPCValueError
from utils import Utils as utils

# Create EC2 client
ec2 = boto3.client("ec2")
ddb_client = boto3.client("dynamodb")

vpc_ddb_table = os.getenv('vpc_info_table') # DynamoDB storing vpc information

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    """

    for record in event['Records']:
        try:
            request_body = json.loads(record['body'])
            request_id = request_body['request_id']
            cidr_range = request_body['vpc_cidr']
            target_account = request_body['aws_account']
            subnet_cidrs = request_body["subnet_cidrs"]
            target_region = request_body['aws_region']
            
            logger.info(f'Starting the provisioning of VPC in region {target_region} in account {target_account} for request {request_id}')
            logger.info(f'Inserting record for this request in DynamoDB table now')

            ddb_client.put_item(TableName=vpc_ddb_table,
                                Item={
                                    "status": {"S": "pending"},
                                    "vpc_cidr": {"S": cidr_range},
                                    "vpc_id": {"S": " "},
                                    "subnet_ids": {"SS": subnet_cidrs},
                                    "request_id": {"S": request_id},
                                    "aws_account": {"S": target_account},
                                    "aws_region": {"S": target_region},
                                    "reason": "N/A",
                                    "creation_time": {"S": datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")}
                                }
            )
                    
            ## Validate if VPC CIDR range provided falls within the allowed range
            if cidr_range in {'0.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16', '224.0.0.0/4'}:
                raise VPCValueError(f'The CIDR block {cidr_range} specified is invalid. Please check AWS documentation for the valid CIDR range')
                   
            
            ## Validate if subnet mask provided for VPC is valid
            vpc_input_subnet_mask = cidr_range.split('/')[1]
            if not 16 <= vpc_input_subnet_mask <= 28:
                raise VPCValueError('The subnet mask specified is invalid. Should be between /16 and /28')
            
            ## Throw an error if another VPC with the overlapping CIDR is found in the region
            existing_cidr_check = utils.check_overlapping_cidr(cidr_range,target_region,target_account)
            if existing_cidr_check:
                raise VPCValueError(f'An existing VPC already exists in the {target_account} for region {target_region}')
            
            ddb_client.update_ddb_status(status='pending',request_id=request_id)
            
            ## Create VPC in target account
            logger.info('Assuming role in target account')
            target_account_session = utils.assume_role_target_account(target_account)   ### Assume role in target account
            target_ec2_client = target_account_session.client("ec2", region_name=target_account)

            vpc_response = target_ec2_client.create_vpc(
                CidrBlock=cidr_range
            )['Vpc']
            
            vpc_id = vpc_response["VpcId"]
            vpc_status = vpc_response['State']

            ## Wait till VPC is in available state
            vpc_waiter = target_ec2_client.get_waiter("vpc_available")
            vpc_waiter.wait(VpcIds=[vpc_id])

            # Enable DNS support and hostnames for VPC
            vpc_dns_update_response = target_ec2_client.modify_vpc_attribute(
                EnableDnsHostnames={'Value': True},
                EnableDnsSupport={'Value': True},
                VpcId=vpc_id
            )
            logger.info(f'VPC {vpc_id} is now in available status')

            subnet_ids = []   #### List to hold ids of subnets to be created
            for subnet_cidr in subnet_cidrs:
                subnet_response = ec2.create_subnet(VpcId=vpc_id, CidrBlock=subnet_cidr)
                subnet_id = subnet_response["Subnet"]["SubnetId"]
                logger.info(f'Subnet {subnet_id} has been created within VPC {vpc_id}')
                subnet_ids.append(subnet_id)
                
            # Creating response payload to be returned to APIGW
            response = {
                'vpc_id': vpc_id,
                'vpc_status': vpc_status,
                'cidr_block': cidr_range,
                'subnet_ids': subnet_ids,
                'message': 'VPC and subnets created successfully!',
                'aws_account': target_account,
                'aws_region': target_region
            }

        except VPCValueError as e:
            logger.error(str(e))
            utils.update_ddb_status(status='error', reason=str(e),request_id=request_id)
            return utils.format_response(500,{'message': str(e)})
        
        except Exception as e:
            logger.exception(f'Encountered error str({e})')
            utils.update_ddb_status(status='error', reason=str(e),request_id=request_id)
            return utils.format_response(500,{'message': str(e)})
        else:
            logger.info(f'VPC has been created succsfully with {vpc_id}')
            logger.info('Updating the status of the provisioned VPC in DynamoDB table')
            utils.update_ddb_status(status='success',request_id=request_id,vpc_id=vpc_id)
            return utils.format_response(200,response)
    