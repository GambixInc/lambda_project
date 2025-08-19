# Frontend API Integration Guide

This guide explains how to integrate with the Strata Projects Lambda function from your frontend application.

## API Endpoint

After deployment, you'll receive an API Gateway URL like:
```
https://abc123.execute-api.us-east-1.amazonaws.com/beta/projects
```

## Making Requests

### Endpoint
```
POST /projects
```

### Headers
```javascript
{
  'Content-Type': 'application/json'
}
```

### Request Body
```javascript
{
  "websiteUrl": "https://example.com",
  "category": "General",
  "description": "Optional project description",
  "scrapedData": {
    // Complete scraped data from your lambda scraper
  },
  "userId": "user_123"
}
```

## JavaScript Examples

### Using Fetch API
```javascript
const createProject = async (projectData) => {
  try {
    const response = await fetch('https://your-api-gateway-url/projects', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(projectData)
    });

    const result = await response.json();
    
    if (response.ok) {
      console.log('Project created successfully:', result.data);
      return result.data;
    } else {
      console.error('Error creating project:', result.error);
      throw new Error(result.error);
    }
  } catch (error) {
    console.error('Request failed:', error);
    throw error;
  }
};

// Usage
const projectData = {
  websiteUrl: 'https://example.com',
  category: 'General',
  description: 'My test project',
  scrapedData: {
    url: 'https://example.com',
    title: 'Example Website',
    content: 'This is the website content...',
    // ... other scraped data
  },
  userId: 'user_123'
};

createProject(projectData)
  .then(project => {
    console.log('Created project:', project);
  })
  .catch(error => {
    console.error('Failed to create project:', error);
  });
```

### Using Axios
```javascript
import axios from 'axios';

const createProject = async (projectData) => {
  try {
    const response = await axios.post('https://your-api-gateway-url/projects', projectData, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    console.log('Project created successfully:', response.data.data);
    return response.data.data;
  } catch (error) {
    console.error('Error creating project:', error.response?.data?.error || error.message);
    throw error;
  }
};
```

### Using React Hook
```javascript
import { useState } from 'react';

const useCreateProject = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const createProject = async (projectData) => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch('https://your-api-gateway-url/projects', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(projectData)
      });

      const result = await response.json();

      if (response.ok) {
        return result.data;
      } else {
        throw new Error(result.error);
      }
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return { createProject, loading, error };
};

// Usage in React component
const ProjectForm = () => {
  const { createProject, loading, error } = useCreateProject();

  const handleSubmit = async (formData) => {
    try {
      const project = await createProject(formData);
      console.log('Project created:', project);
      // Handle success (redirect, show notification, etc.)
    } catch (err) {
      // Handle error (show error message, etc.)
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}
      <button type="submit" disabled={loading}>
        {loading ? 'Creating...' : 'Create Project'}
      </button>
    </form>
  );
};
```

## Response Format

### Success Response (201 Created)
```javascript
{
  "success": true,
  "data": {
    "user_id": "user_123",
    "project_id": "project_abc123def456",
    "website_url": "https://example.com",
    "category": "General",
    "description": "Optional project description",
    "title": "Website Title",
    "health_score": 85,
    "last_checked": "2025-08-18T19:46:59.000Z",
    "status": "active",
    "created_at": "2025-08-18T19:46:59.000Z",
    "updated_at": "2025-08-18T19:46:59.000Z",
    "scraped_data": {
      // Complete scraped data
    }
  },
  "message": "Project created successfully"
}
```

### Error Response (400/409/500)
```javascript
{
  "success": false,
  "error": "Error message",
  "message": "Detailed error description"
}
```

## Error Handling

### Common Error Codes
- **400 Bad Request**: Missing required fields or invalid data
- **409 Conflict**: Project already exists for this URL
- **500 Internal Server Error**: Server-side error

### Error Handling Example
```javascript
const handleApiError = (error) => {
  if (error.response) {
    // Server responded with error status
    const { status, data } = error.response;
    
    switch (status) {
      case 400:
        return `Invalid request: ${data.error}`;
      case 409:
        return 'A project already exists for this website URL';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return `Unexpected error (${status}): ${data.error}`;
    }
  } else if (error.request) {
    // Network error
    return 'Network error. Please check your connection.';
  } else {
    // Other error
    return error.message;
  }
};
```

## Required Fields

### Mandatory
- `websiteUrl` (string): The URL of the website being analyzed
- `scrapedData` (object): Complete scraped data from your lambda scraper

### Optional
- `category` (string): Project category (default: "General")
- `description` (string): Optional project description
- `userId` (string): User identifier (default: "default_user")

## Scraped Data Structure

The `scrapedData` field should contain the complete response from your lambda scraper. At minimum, it must include:

```javascript
{
  "url": "https://example.com",
  "title": "Website Title",
  "content": "Extracted text content"
}
```

For full functionality, include all available scraped data fields as specified in the main API documentation.

## CORS

The API is configured to allow cross-origin requests from any domain. The Lambda function handles CORS preflight requests automatically, so no additional CORS configuration is needed on the frontend.

**Note:** If you encounter CORS errors, make sure you've deployed the latest version of the Lambda function that includes proper CORS handling.

## Testing

### Test with curl
```bash
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
```

### Test in Browser Console
```javascript
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
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

## Environment Variables

Store your API URL in environment variables:

```javascript
// .env file
REACT_APP_API_URL=https://your-api-gateway-url/projects

// Usage
const API_URL = process.env.REACT_APP_API_URL;
```

## Security Notes

- The API is currently public (no authentication required)
- Consider implementing rate limiting on the frontend
- Validate data before sending to the API
- Handle sensitive data appropriately
