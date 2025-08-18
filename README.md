# Lambda Project - Create Project API

This project implements a Lambda function that creates projects and saves comprehensive website analysis data to a DynamoDB table. The API is designed to work with scraped website data from a lambda scraper.

## Features

- **POST /api/projects** - Create new projects with scraped website data
- **DynamoDB Integration** - Stores complete project data including scraped information
- **Health Score Calculation** - Automatically calculates website health scores
- **Duplicate Prevention** - Prevents creating duplicate projects for the same URL
- **CORS Support** - Configured for cross-origin requests
- **Comprehensive Validation** - Validates URLs, data structure, and required fields
- **Error Handling** - Proper error responses with meaningful messages

## Architecture

```
Frontend → API Gateway → Lambda Function → DynamoDB
```

### Components

1. **API Gateway** - HTTP endpoint for POST requests
2. **Lambda Function** - Python function that processes requests (`lambda_function.py`)
3. **DynamoDB Table** - Stores project data with indexes for efficient querying
4. **IAM Roles** - Proper permissions for Lambda to access DynamoDB

## DynamoDB Schema

### Strata Projects Table
- **Primary Key**: 
  - **Partition Key**: `user_id` (String) - User identifier
  - **Sort Key**: `project_id` (String) - Unique project identifier within user
- **GSI**: `website_url` (String) - For duplicate checking and URL-based queries

### Benefits of This Design:
- **Efficient User Queries**: Query all projects for a user using just the partition key (`user_id`)
- **Unique Projects**: Each project has a unique `project_id` within a user's scope
- **Duplicate Prevention**: Efficient duplicate checking using the GSI on `website_url`
- **Scalability**: Projects are distributed across users, preventing hot partitions
- **Cost Optimization**: Queries by `user_id` are more efficient than scans

### Required DynamoDB Table
You'll need to create a DynamoDB table with this structure:
- **Table Name**: `strata_projects-beta`
- **Partition Key**: `user_id` (String)
- **Sort Key**: `project_id` (String)
- **GSI**: `website_url` (String)

### Project Item Structure
```json
{
  "user_id": "user_123",
  "project_id": "project_abc123def456",
  "website_url": "https://example.com",
  "category": "General",
  "description": "Project description",
  "title": "Website Title",
  "health_score": 85,
  "last_checked": "2025-08-18T19:46:59.000Z",
  "status": "active",
  "created_at": "2025-08-18T19:46:59.000Z",
  "updated_at": "2025-08-18T19:46:59.000Z",
  "scraped_data": {
    // Complete scraped data object
  }
}
```

## API Specification

### Endpoint
`POST /api/projects`

### Request Body
```json
{
  "websiteUrl": "https://example.com",
  "category": "General",
  "description": "Optional project description",
  "scrapedData": {
    // Complete scraped data from lambda scraper
  },
  "userId": "user_123"
}
```

### Response Format

#### Success (201 Created)
```json
{
  "success": true,
  "data": {
    "user_id": "user_123",
    "project_id": "project_123",
    "websiteUrl": "https://example.com",
    "category": "General",
    "description": "Optional project description",
    "title": "Website Title",
    "healthScore": 85,
    "lastChecked": "2025-08-18T19:46:59.000Z",
    "status": "active",
    "createdAt": "2025-08-18T19:46:59.000Z",
    "updatedAt": "2025-08-18T19:46:59.000Z",
    "scrapedData": {
      // Complete scraped data
    }
  },
  "message": "Project created successfully"
}
```

#### Error (400/409/500)
```json
{
  "success": false,
  "error": "Error message",
  "message": "Detailed error description"
}
```

## Health Score Calculation

The function calculates a health score (0-100) based on:

- **HTTP Status Code** (20 points for 200)
- **Content Quality** (10-20 points based on content length)
- **Meta Information** (10-15 points for title/description)
- **Link Count** (10-15 points based on number of links)
- **SSL Security** (10 points for HTTPS)
- **Modern Frameworks** (10 points for React/Vue/Angular)

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.9+
- Required Python packages (see `requirements.txt`)

## Deployment

### Quick Deploy (Recommended)
```bash
# Deploy to beta environment (uses dev-account profile by default)
./deploy.sh beta

# Deploy to specific region
./deploy.sh beta us-west-2

# Deploy with custom profile
./deploy.sh beta us-east-1 my-custom-profile
```

### Manual Deployment Options

#### Option 1: AWS Console
1. Create a new Lambda function in the AWS Console
2. Upload the `lambda_function.py` file
3. Set the handler to `lambda_function.lambda_handler`
4. Configure environment variables:
   - `TABLE_NAME`: `strata_projects-beta`
5. Set up API Gateway trigger for HTTP POST requests

#### Option 2: AWS CLI
```bash
# Install dependencies
pip install -r requirements.txt

# Create deployment package
zip -r lambda-deployment.zip lambda_function.py

# Create Lambda function
aws lambda create-function \
  --function-name strata_projects-beta \
  --runtime python3.9 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda-deployment.zip \
  --role arn:aws:iam::YOUR_ACCOUNT:role/lambda-execution-role \
  --environment Variables='{TABLE_NAME=strata_projects-beta}'
```

#### Option 3: Infrastructure as Code
Use your preferred IaC tool (Terraform, CDK, etc.) to deploy the Lambda function and API Gateway.

## API Endpoint

Once deployed, you'll have an HTTP endpoint like:
```
POST https://your-api-gateway-url/projects
```

### 4. Use the API Endpoint
```bash
# From your frontend
curl -X POST https://your-api-gateway-url/projects \
  -H 'Content-Type: application/json' \
  -d '{
    "websiteUrl": "https://example.com",
    "category": "General",
    "description": "Test project",
    "scrapedData": {
      "url": "https://example.com",
      "title": "Example",
      "content": "Test content"
    },
    "userId": "test_user"
  }'

# From JavaScript/frontend
fetch('https://your-api-gateway-url/projects', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    websiteUrl: 'https://example.com',
    category: 'General',
    description: 'Test project',
    scrapedData: {
      url: 'https://example.com',
      title: 'Example',
      content: 'Test content'
    },
    userId: 'test_user'
  })
})
```





## Validation Rules

### Required Fields
- `websiteUrl` - Must be a valid HTTP/HTTPS URL
- `scrapedData` - Must contain `url`, `title`, and `content` fields

### Validation Checks
- URL format validation
- Scraped data structure validation
- Duplicate project prevention (same user + URL)
- JSON format validation

## Error Handling

| Status Code | Error Type | Description |
|-------------|------------|-------------|
| 400 | Bad Request | Missing required fields, invalid data |
| 405 | Method Not Allowed | Only POST method is supported |
| 409 | Conflict | Project already exists for this URL |
| 500 | Internal Server Error | Server-side error |

## Security Considerations

- **No Authentication** - Currently public (as requested)
- **Input Validation** - All inputs are validated and sanitized
- **CORS** - Configured for cross-origin requests
- **IAM Permissions** - Least privilege access to DynamoDB

## Monitoring and Logging

- CloudWatch Logs for Lambda function execution
- DynamoDB metrics for table performance
- API Gateway access logs

## Cost Optimization

- **DynamoDB On-Demand** - Pay per request, no capacity planning needed
- **Lambda Timeout** - Set to 30 seconds to prevent excessive charges
- **Memory Allocation** - 256MB (adequate for the workload)

## Future Enhancements

1. **Authentication** - Add JWT or Cognito authentication
2. **Rate Limiting** - Implement API Gateway rate limiting
3. **Data Archival** - Move old projects to cheaper storage
4. **Health Score Improvements** - More sophisticated scoring algorithm
5. **Batch Operations** - Support for creating multiple projects
6. **Project Updates** - PUT/PATCH endpoints for updating projects

## Troubleshooting

### Common Issues

1. **Lambda Function Errors**
   - Check CloudWatch logs for error details
   - Verify IAM permissions for DynamoDB access
   - Ensure DynamoDB table exists

2. **Lambda Timeout**
   - Check DynamoDB table performance
   - Verify network connectivity
   - Review function logs in CloudWatch

3. **CORS Errors**
   - Verify API Gateway CORS configuration
   - Check request headers

4. **DynamoDB Errors**
   - Verify table exists and is accessible
   - Check IAM permissions
   - Review table capacity settings

### Debugging

```bash
# View Lambda function logs
aws logs tail /aws/lambda/strata_projects-beta --follow --profile dev-account

# Test DynamoDB connectivity
aws dynamodb scan --table-name strata_projects-beta --limit 1 --profile dev-account

# Query projects for a specific user
aws dynamodb query --table-name strata_projects-beta --key-condition-expression "user_id = :user_id" --expression-attribute-values '{":user_id":{"S":"user_123"}}' --profile dev-account

# Get a specific project
aws dynamodb get-item --table-name strata_projects-beta --key '{"user_id":{"S":"user_123"},"project_id":{"S":"project_abc123"}}' --profile dev-account
```

## Support

For issues or questions:
1. Check CloudWatch logs for error details
2. Review API Gateway access logs
3. Verify DynamoDB table status
4. Test with the provided test script

## License

This project is provided as-is for educational and development purposes.