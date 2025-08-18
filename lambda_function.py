import json
import boto3
import uuid
import re
import os
from datetime import datetime
from urllib.parse import urlparse
from typing import Dict, Any, Optional

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'strata_projects-beta')
table = dynamodb.Table(table_name)

def create_response(data, status_code=200, is_api_gateway=False):
    """Create a response in the appropriate format."""
    if is_api_gateway:
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps(data)
        }
    else:
        return data

def validate_url(url: str) -> bool:
    """Validate if the provided URL is valid."""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False

def validate_scraped_data(data: Dict[str, Any]) -> bool:
    """Validate the structure of scraped data."""
    required_fields = ['url', 'title', 'content']
    return all(field in data for field in required_fields)

def calculate_health_score(scraped_data: Dict[str, Any]) -> int:
    """Calculate a health score based on scraped data."""
    score = 0
    
    # Basic checks
    if scraped_data.get('status_code', 0) == 200:
        score += 20
    
    # Content quality
    content_length = scraped_data.get('content_length', 0)
    if content_length > 1000:
        score += 20
    elif content_length > 500:
        score += 10
    
    # Meta information
    if scraped_data.get('title'):
        score += 15
    if scraped_data.get('description'):
        score += 10
    
    # Links
    links_count = scraped_data.get('links_count', 0)
    if links_count > 10:
        score += 15
    elif links_count > 5:
        score += 10
    
    # SSL
    if scraped_data.get('has_ssl', False):
        score += 10
    
    # Framework detection (modern frameworks)
    framework_data = scraped_data.get('framework_detection', {})
    if any(framework_data.get(fw, False) for fw in ['react', 'vue', 'angular']):
        score += 10
    
    return min(score, 100)

def generate_project_id() -> str:
    """Generate a unique project ID."""
    return f"project_{uuid.uuid4().hex[:12]}"

def create_project(user_id: str, website_url: str, category: str, description: str, scraped_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new project in DynamoDB."""
    project_id = generate_project_id()
    current_time = datetime.utcnow().isoformat() + 'Z'
    
    # Calculate health score
    health_score = calculate_health_score(scraped_data)
    
    # Prepare project item
    project_item = {
        'user_id': user_id,
        'project_id': project_id,
        'website_url': website_url,
        'category': category,
        'description': description,
        'title': scraped_data.get('title', website_url),
        'health_score': health_score,
        'last_checked': current_time,
        'status': 'active',
        'created_at': current_time,
        'updated_at': current_time,
        'scraped_data': scraped_data
    }
    
    # Save to DynamoDB
    table.put_item(Item=project_item)
    
    return project_item

def check_duplicate_project(user_id: str, website_url: str) -> bool:
    """Check if a project already exists for the user and URL."""
    try:
        # Query by user_id (partition key) and filter by website_url
        response = table.query(
            KeyConditionExpression='user_id = :user_id',
            FilterExpression='website_url = :website_url',
            ExpressionAttributeValues={
                ':user_id': user_id,
                ':website_url': website_url
            }
        )
        return len(response.get('Items', [])) > 0
    except Exception as e:
        print(f"Error checking for duplicate project: {e}")
        return False

def lambda_handler(event, context):
    """Main Lambda function handler."""
    try:
        # Parse the event - can be direct invocation or from other AWS services
        is_api_gateway = isinstance(event, dict) and 'body' in event
        
        if is_api_gateway:
            # API Gateway event format
            try:
                body = json.loads(event.get('body', '{}'))
            except json.JSONDecodeError:
                return create_response({
                    'success': False,
                    'error': 'Invalid JSON in request body'
                }, 400, True)
        else:
            # Direct invocation - event is the data directly
            body = event
        
        # Extract required fields
        website_url = body.get('websiteUrl')
        category = body.get('category', 'General')
        description = body.get('description', '')
        scraped_data = body.get('scrapedData')
        
        # For now, use a default user ID since we're not implementing authentication
        user_id = body.get('userId', 'default_user')
        
        # Validation
        if not website_url:
            return create_response({
                'success': False,
                'error': 'websiteUrl is required'
            }, 400, is_api_gateway)
        
        if not scraped_data:
            return create_response({
                'success': False,
                'error': 'scrapedData is required'
            }, 400, is_api_gateway)
        
        # Validate URL
        if not validate_url(website_url):
            return create_response({
                'success': False,
                'error': 'Invalid website URL format'
            }, 400, is_api_gateway)
        
        # Validate scraped data
        if not validate_scraped_data(scraped_data):
            return create_response({
                'success': False,
                'error': 'Invalid scraped data structure'
            }, 400, is_api_gateway)
        
        # Check for duplicate project
        if check_duplicate_project(user_id, website_url):
            return create_response({
                'success': False,
                'error': 'Project already exists for this URL'
            }, 409, is_api_gateway)
        
        # Create the project
        project = create_project(user_id, website_url, category, description, scraped_data)
        
        # Return success response
        return create_response({
            'success': True,
            'data': project,
            'message': 'Project created successfully'
        }, 201, is_api_gateway)
        
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return create_response({
            'success': False,
            'error': 'Internal server error',
            'message': str(e)
        }, 500, is_api_gateway)
