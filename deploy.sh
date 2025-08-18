#!/bin/bash

# Deployment script for Lambda function
set -e

# Configuration
STACK_NAME="lambda-project-stack"
ENVIRONMENT=${1:-beta}
REGION=${2:-us-east-1}
AWS_PROFILE=${3:-dev-account}

echo "Deploying Lambda function to environment: $ENVIRONMENT in region: $REGION"

# Create deployment package
echo "Creating deployment package..."
rm -rf deployment-package
mkdir deployment-package

# Copy Lambda function
cp lambda_function.py deployment-package/

# Install dependencies
pip install -r requirements.txt -t deployment-package/

# Create ZIP file
cd deployment-package
zip -r ../lambda-deployment.zip .
cd ..

# Create CloudFormation template
cat > template.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lambda function for creating projects with DynamoDB storage'

Parameters:
  Environment:
    Type: String
    Default: beta
    Description: Environment name (beta, staging, prod)

Resources:
  # DynamoDB Table
  ProjectsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub 'strata_projects-${Environment}'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: user_id
          AttributeType: S
        - AttributeName: project_id
          AttributeType: S
        - AttributeName: website_url
          AttributeType: S
      KeySchema:
        - AttributeName: user_id
          KeyType: HASH
        - AttributeName: project_id
          KeyType: RANGE
      GlobalSecondaryIndexes:
        - IndexName: WebsiteUrlIndex
          KeySchema:
            - AttributeName: website_url
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # IAM Role for Lambda
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:UpdateItem
                  - dynamodb:DeleteItem
                  - dynamodb:Query
                  - dynamodb:Scan
                Resource:
                  - !GetAtt ProjectsTable.Arn
                  - !Sub '${ProjectsTable.Arn}/index/*'

  # Lambda Function
  CreateProjectFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub 'strata_projects-${Environment}'
      Runtime: python3.9
      Handler: lambda_function.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          # This will be replaced by the actual lambda_function.py during deployment
      Environment:
        Variables:
          TABLE_NAME: !Ref ProjectsTable
          ENVIRONMENT: !Ref Environment
      Timeout: 30
      MemorySize: 256
      Tags:
        - Key: Environment
          Value: !Ref Environment

  # API Gateway
  ApiGateway:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub 'strata-projects-api-${Environment}'
      Description: API Gateway for strata projects
      EndpointConfiguration:
        Types:
          - REGIONAL

  # API Gateway Resource
  ApiResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ApiGateway
      ParentId: !GetAtt ApiGateway.RootResourceId
      PathPart: projects

  # API Gateway Method
  ApiMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !Ref ApiResource
      HttpMethod: POST
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${CreateProjectFunction.Arn}/invocations'

  # Lambda Permission for API Gateway
  LambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref CreateProjectFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*'

  # API Gateway Deployment
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn: ApiMethod
    Properties:
      RestApiId: !Ref ApiGateway
      StageName: !Ref Environment

Outputs:
  DynamoDBTableName:
    Description: Name of the DynamoDB table
    Value: !Ref ProjectsTable
    Export:
      Name: !Sub '${AWS::StackName}-TableName'

  LambdaFunctionArn:
    Description: ARN of the Lambda function
    Value: !GetAtt CreateProjectFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-LambdaArn'

  ApiGatewayUrl:
    Description: URL of the API Gateway endpoint
    Value: !Sub 'https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/${Environment}/projects'
    Export:
      Name: !Sub '${AWS::StackName}-ApiUrl'
EOF

# Deploy using CloudFormation
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --profile $AWS_PROFILE

# Get the API Gateway URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --profile $AWS_PROFILE \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text)

# Update Lambda function with actual code
echo "Updating Lambda function with actual code..."
aws lambda update-function-code \
    --function-name strata_projects-$ENVIRONMENT \
    --zip-file fileb://lambda-deployment.zip \
    --region $REGION \
    --profile $AWS_PROFILE

# Clean up
rm -f template.yaml
rm -rf deployment-package
rm -f lambda-deployment.zip

echo "Deployment complete!"
echo "API Gateway URL: $API_URL"
