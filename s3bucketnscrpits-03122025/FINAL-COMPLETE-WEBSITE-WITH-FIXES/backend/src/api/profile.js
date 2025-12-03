const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Helper function to verify JWT token
const verifyToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET || 'cloudnestle-secret');
  } catch (error) {
    throw new Error('Invalid token');
  }
};

// Helper function to get user from token
const getUserFromToken = (event) => {
  const authHeader = event.headers.Authorization || event.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Missing or invalid authorization header');
  }
  
  const token = authHeader.substring(7);
  return verifyToken(token);
};

// GET /api/profile - Get user profile
exports.getHandler = async (event) => {
  try {
    const user = getUserFromToken(event);
    
    // Get profile data from DynamoDB
    const result = await dynamodb.get({
      TableName: process.env.DYNAMODB_TABLE,
      Key: { userId: user.sub }
    }).promise();
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Allow-Methods': 'GET'
        },
        body: JSON.stringify({
          error: 'Profile not found',
          message: 'User profile does not exist'
        })
      };
    }
    
    // Remove sensitive information
    const profile = { ...result.Item };
    delete profile.createdAt;
    delete profile.updatedAt;
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'GET'
      },
      body: JSON.stringify({
        success: true,
        profile: profile
      })
    };
    
  } catch (error) {
    console.error('Get profile error:', error);
    
    return {
      statusCode: error.message === 'Invalid token' ? 401 : 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to get profile',
        message: error.message
      })
    };
  }
};

// PUT /api/profile - Update user profile
exports.updateHandler = async (event) => {
  try {
    const user = getUserFromToken(event);
    const updates = JSON.parse(event.body);
    
    // Validate allowed fields
    const allowedFields = [
      'name', 'company', 'role', 'industry', 'companySize', 
      'preferences', 'notifications', 'timezone', 'avatar'
    ];
    
    const updateData = {};
    Object.keys(updates).forEach(key => {
      if (allowedFields.includes(key)) {
        updateData[key] = updates[key];
      }
    });
    
    if (Object.keys(updateData).length === 0) {
      return {
        statusCode: 400,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Allow-Methods': 'PUT'
        },
        body: JSON.stringify({
          error: 'No valid fields to update',
          message: 'Please provide valid fields to update'
        })
      };
    }
    
    // Build update expression
    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};
    
    Object.keys(updateData).forEach((key, index) => {
      const attrName = `#attr${index}`;
      const attrValue = `:val${index}`;
      
      updateExpressions.push(`${attrName} = ${attrValue}`);
      expressionAttributeNames[attrName] = key;
      expressionAttributeValues[attrValue] = updateData[key];
    });
    
    // Add updatedAt timestamp
    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();
    
    // Update profile in DynamoDB
    const updateParams = {
      TableName: process.env.DYNAMODB_TABLE,
      Key: { userId: user.sub },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };
    
    const result = await dynamodb.update(updateParams).promise();
    
    // Update Cognito user attributes if name changed
    if (updateData.name) {
      try {
        await cognito.adminUpdateUserAttributes({
          UserPoolId: process.env.COGNITO_USER_POOL_ID,
          Username: user.sub,
          UserAttributes: [
            {
              Name: 'name',
              Value: updateData.name
            }
          ]
        }).promise();
      } catch (cognitoError) {
        console.warn('Failed to update Cognito attributes:', cognitoError);
      }
    }
    
    // Remove sensitive information from response
    const updatedProfile = { ...result.Attributes };
    delete updatedProfile.createdAt;
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'PUT'
      },
      body: JSON.stringify({
        success: true,
        message: 'Profile updated successfully',
        profile: updatedProfile
      })
    };
    
  } catch (error) {
    console.error('Update profile error:', error);
    
    return {
      statusCode: error.message === 'Invalid token' ? 401 : 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to update profile',
        message: error.message
      })
    };
  }
};

// DELETE /api/profile - Delete user profile
exports.deleteHandler = async (event) => {
  try {
    const user = getUserFromToken(event);
    
    // Delete from DynamoDB
    await dynamodb.delete({
      TableName: process.env.DYNAMODB_TABLE,
      Key: { userId: user.sub }
    }).promise();
    
    // Delete from Cognito
    await cognito.adminDeleteUser({
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: user.sub
    }).promise();
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'DELETE'
      },
      body: JSON.stringify({
        success: true,
        message: 'Profile deleted successfully'
      })
    };
    
  } catch (error) {
    console.error('Delete profile error:', error);
    
    return {
      statusCode: error.message === 'Invalid token' ? 401 : 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to delete profile',
        message: error.message
      })
    };
  }
};

// GET /api/profile/stats - Get user statistics
exports.getStatsHandler = async (event) => {
  try {
    const user = getUserFromToken(event);
    
    // Get profile data from DynamoDB
    const result = await dynamodb.get({
      TableName: process.env.DYNAMODB_TABLE,
      Key: { userId: user.sub }
    }).promise();
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        body: JSON.stringify({
          error: 'Profile not found'
        })
      };
    }
    
    const profile = result.Item;
    
    // Calculate user statistics
    const stats = {
      memberSince: profile.createdAt,
      lastLogin: profile.lastLoginAt,
      loginCount: profile.loginCount || 0,
      subscriptionTier: profile.subscriptionTier || 'free',
      assessmentsCompleted: profile.assessmentsCompleted || 0,
      consultationHours: profile.consultationHours || 0,
      certificationsEarned: profile.certificationsEarned || 0,
      communityPoints: profile.communityPoints || 0,
      learningProgress: profile.learningProgress || {},
      achievements: profile.achievements || []
    };
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'GET'
      },
      body: JSON.stringify({
        success: true,
        stats: stats
      })
    };
    
  } catch (error) {
    console.error('Get stats error:', error);
    
    return {
      statusCode: error.message === 'Invalid token' ? 401 : 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to get statistics',
        message: error.message
      })
    };
  }
};
