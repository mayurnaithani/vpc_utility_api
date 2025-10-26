# vpc_utility_api
This repository implements Serverless solution to host public APIs in AWS APIGW to support management of VPC in AWS.
Cross account and cross region VPC creation is supported within an AWS Organization.
API requests are validated via Cognito user pools, queued, and asynchronously processed using AWS Lambda and SQS, with results stored in DynamoDB.

# Workflow
POST 

User ------> API GW ------>  SQS ------> Lambda -------> DynamoDB
            (Cognito)                 Event source
                                         mapping
GET

User ------> API GW ------> Lambda <------- DynamoDB
            (Cognito)                 

    
  
