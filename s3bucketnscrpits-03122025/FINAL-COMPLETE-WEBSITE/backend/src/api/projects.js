// Project management API endpoints
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Get user projects
exports.getProjects = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    
    const result = await dynamodb.query({
      TableName: process.env.PROJECTS_TABLE,
      IndexName: 'UserIdIndex',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId
      }
    }).promise();

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
      },
      body: JSON.stringify({
        projects: result.Items || []
      })
    };
  } catch (error) {
    console.error('Get projects error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to retrieve projects',
        message: error.message
      })
    };
  }
};

// Create new project
exports.createProject = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const projectData = JSON.parse(event.body);
    
    const project = {
      projectId: uuidv4(),
      userId,
      ...projectData,
      status: 'planning',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    await dynamodb.put({
      TableName: process.env.PROJECTS_TABLE,
      Item: project
    }).promise();

    return {
      statusCode: 201,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
      },
      body: JSON.stringify({
        message: 'Project created successfully',
        project
      })
    };
  } catch (error) {
    console.error('Create project error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to create project',
        message: error.message
      })
    };
  }
};

// Update project
exports.updateProject = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const { projectId } = event.pathParameters;
    const updateData = JSON.parse(event.body);
    
    await dynamodb.update({
      TableName: process.env.PROJECTS_TABLE,
      Key: { projectId },
      UpdateExpression: 'SET #status = :status, progress = :progress, updatedAt = :timestamp',
      ConditionExpression: 'userId = :userId',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': updateData.status,
        ':progress': updateData.progress,
        ':userId': userId,
        ':timestamp': new Date().toISOString()
      }
    }).promise();

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
      },
      body: JSON.stringify({
        message: 'Project updated successfully'
      })
    };
  } catch (error) {
    console.error('Update project error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to update project',
        message: error.message
      })
    };
  }
};
