// Notification system for user alerts and updates
const AWS = require('aws-sdk');
const ses = new AWS.SES();
const dynamodb = new AWS.DynamoDB.DocumentClient();

// Get user notifications
exports.getNotifications = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    
    const result = await dynamodb.query({
      TableName: process.env.NOTIFICATIONS_TABLE,
      IndexName: 'UserIdIndex',
      KeyConditionExpression: 'userId = :userId',
      ScanIndexForward: false, // Most recent first
      Limit: 50,
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
        notifications: result.Items || []
      })
    };
  } catch (error) {
    console.error('Get notifications error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to retrieve notifications',
        message: error.message
      })
    };
  }
};

// Mark notification as read
exports.markAsRead = async (event) => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const { notificationId } = event.pathParameters;
    
    await dynamodb.update({
      TableName: process.env.NOTIFICATIONS_TABLE,
      Key: { notificationId },
      UpdateExpression: 'SET #read = :read, readAt = :timestamp',
      ConditionExpression: 'userId = :userId',
      ExpressionAttributeNames: {
        '#read': 'read'
      },
      ExpressionAttributeValues: {
        ':read': true,
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
        message: 'Notification marked as read'
      })
    };
  } catch (error) {
    console.error('Mark notification error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to mark notification as read',
        message: error.message
      })
    };
  }
};

// Send email notification
exports.sendEmailNotification = async (event) => {
  try {
    const { email, subject, message, type } = JSON.parse(event.body);
    
    const params = {
      Destination: {
        ToAddresses: [email]
      },
      Message: {
        Body: {
          Html: {
            Data: `
              <html>
                <body>
                  <h2>CloudNestle Notification</h2>
                  <p>${message}</p>
                  <hr>
                  <p><small>This is an automated message from CloudNestle Academy.</small></p>
                </body>
              </html>
            `
          },
          Text: {
            Data: message
          }
        },
        Subject: {
          Data: subject
        }
      },
      Source: process.env.FROM_EMAIL
    };

    await ses.sendEmail(params).promise();

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
      },
      body: JSON.stringify({
        message: 'Email notification sent successfully'
      })
    };
  } catch (error) {
    console.error('Send email error:', error);
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to send email notification',
        message: error.message
      })
    };
  }
};
