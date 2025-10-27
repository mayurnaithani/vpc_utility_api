# vpc_utility_api
This repository implements Serverless solution to host public APIs in AWS APIGW to support management of VPC in AWS.
Cross account and cross region VPC creation is supported within an AWS Organization.
API requests are validated via Cognito user pools, queued, and asynchronously processed using AWS Lambda and SQS, with results stored in DynamoDB.

# Workflow
#### **POST — Create VPC**

User ------> API GW ------>  SQS ------> Lambda -------> DynamoDB
            
#### **GET — Get details of VPC**

User ------> API GW ------> Lambda <------- DynamoDB
            (Cognito)                 

### Components:
- **API Gateway (POST /create-vpc)**  
  - Hosts public GET and POST endpoints.
  - Both endpoints integrated with Cognito pools for authentication.
  
- **SQS Queue**  
  - Enables async processing of requests from multiple users.

- **Lambda: `create_vpc_lambda`**  
  - Receives message from SQS lambda via EventSourceMapping. BatchSize has been set to 1.
  - Performs validation of the input request.  
  - Assumes IAM role in target AWS account.  
  - Creates VPC and subnets in target AWS account and region.  
  - Updates status in DynamoDB.

- **Lambda: `get_vpc_lambda`**  
  - Receives input requestId from user.
  - Fetches the provisioning status of the request from DynamoDB table.

- **DynamoDB Table: `vpc_info_table`**
  - Stores record for every provisioning request received.

### How to use this repo:
  - Clone this repository from develop branch.
  - Under infra/terraform/modules folder edit terraform.tfvars as per your values.
  - Run terraform plan, terraform apply to deploy the infra.
  - (Note: We are using a pre-configured Cognito pool here which is provisioned outside of Terraform)

### How to invoke API:
- **API Gateway (POST /create)**
- Triggers VPC creation asynchronously.
- Request Payload:
- {
  "aws_account": "1234567890",
  "region": "us-east-1",
  "cidr_range": "10.0.0.0/16"
  "subnet_ids": ["10.0.0.1/24", "10.0.0.2/24"]
  } 
- Response :
- {
  "request_id": "req-1f9c0b48-8e31-4a71-bc76-8b38e4c372a2"
}
- **API Gateway (GET /info/{request_id})**
- Fetches provisioning status of the VPC.
