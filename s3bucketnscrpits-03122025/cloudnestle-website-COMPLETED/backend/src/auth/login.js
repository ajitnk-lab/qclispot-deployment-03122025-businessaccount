const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  try {
    const { email, password } = JSON.parse(event.body);
    
    // Validate input
    if (!email || !password) {
      return {
        statusCode: 400,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Allow-Methods': 'POST'
        },
        body: JSON.stringify({
          error: 'Missing required fields',
          message: 'Email and password are required'
        })
      };
    }
    
    // Authenticate with Cognito
    const authParams = {
      AuthFlow: 'ADMIN_NO_SRP_AUTH',
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        USERNAME: email,
        PASSWORD: password
      }
    };
    
    const authResult = await cognito.adminInitiateAuth(authParams).promise();
    
    // Get user attributes from Cognito
    const userParams = {
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: email
    };
    
    const userResult = await cognito.adminGetUser(userParams).promise();
    
    // Extract user attributes
    const userAttributes = {};
    userResult.UserAttributes.forEach(attr => {
      userAttributes[attr.Name] = attr.Value;
    });
    
    // Get additional profile data from DynamoDB
    let profileData = {};
    try {
      const profileResult = await dynamodb.get({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { userId: userResult.Username }
      }).promise();
      
      if (profileResult.Item) {
        profileData = profileResult.Item;
      }
    } catch (profileError) {
      console.log('Profile data not found, using basic info');
    }
    
    // Update last login time
    try {
      await dynamodb.update({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { userId: userResult.Username },
        UpdateExpression: 'SET lastLoginAt = :timestamp, loginCount = if_not_exists(loginCount, :zero) + :one',
        ExpressionAttributeValues: {
          ':timestamp': new Date().toISOString(),
          ':zero': 0,
          ':one': 1
        }
      }).promise();
    } catch (updateError) {
      console.log('Failed to update login stats:', updateError);
    }
    
    // Prepare user profile
    const userProfile = {
      userId: userResult.Username,
      email: userAttributes.email || email,
      name: userAttributes.name || profileData.name || '',
      company: profileData.company || '',
      role: profileData.role || '',
      industry: profileData.industry || '',
      companySize: profileData.companySize || '',
      preferences: profileData.preferences || {},
      subscriptions: profileData.subscriptions || [],
      lastLoginAt: new Date().toISOString(),
      emailVerified: userAttributes.email_verified === 'true'
    };
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST'
      },
      body: JSON.stringify({
        message: 'Login successful',
        token: authResult.AuthenticationResult.AccessToken,
        refreshToken: authResult.AuthenticationResult.RefreshToken,
        idToken: authResult.AuthenticationResult.IdToken,
        expiresIn: authResult.AuthenticationResult.ExpiresIn,
        user: userProfile
      })
    };
    
  } catch (error) {
    console.error('Login error:', error);
    
    // Handle specific Cognito errors
    let errorMessage = 'Authentication failed';
    let statusCode = 401;
    
    if (error.code === 'NotAuthorizedException') {
      errorMessage = 'Invalid email or password';
    } else if (error.code === 'UserNotConfirmedException') {
      errorMessage = 'Please verify your email address before logging in';
      statusCode = 403;
    } else if (error.code === 'UserNotFoundException') {
      errorMessage = 'User not found. Please check your email address.';
      statusCode = 404;
    } else if (error.code === 'TooManyRequestsException') {
      errorMessage = 'Too many login attempts. Please try again later.';
      statusCode = 429;
    }
    
    return {
      statusCode: statusCode,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST'
      },
      body: JSON.stringify({
        error: 'Authentication failed',
        message: errorMessage,
        code: error.code
      })
    };
  }
};
