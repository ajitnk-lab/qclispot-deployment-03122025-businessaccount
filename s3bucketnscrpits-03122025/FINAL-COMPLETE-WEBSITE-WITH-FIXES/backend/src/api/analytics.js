// Analytics API endpoints for authenticated users
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Get user analytics data
exports.getUserAnalytics = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    
    // Get user analytics data
    const analyticsData = await dynamodb.get({
      TableName: process.env.ANALYTICS_TABLE,
      Key: { userId }
    }).promise();

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
      },
      body: JSON.stringify({
        analytics: analyticsData.Item || {},
        timestamp: new Date().toISOString()
      })
    };
  } catch (error) {
    console.error('Analytics error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to retrieve analytics',
        message: error.message
      })
    };
  }
};

// Update user analytics
exports.updateAnalytics = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const { action, data } = JSON.parse(event.body);
    
    // Update analytics data
    await dynamodb.update({
      TableName: process.env.ANALYTICS_TABLE,
      Key: { userId },
      UpdateExpression: 'SET #action = :data, updatedAt = :timestamp',
      ExpressionAttributeNames: {
        '#action': action
      },
      ExpressionAttributeValues: {
        ':data': data,
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
        message: 'Analytics updated successfully'
      })
    };
  } catch (error) {
    console.error('Analytics update error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to update analytics',
        message: error.message
      })
    };
  }
};
