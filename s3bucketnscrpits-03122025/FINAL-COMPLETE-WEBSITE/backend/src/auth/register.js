/**
 * CloudNestle User Registration Handler
 * Competitive Advantage: Industry-specific user onboarding with AI-powered recommendations
 */

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const Joi = require('joi');

// Initialize AWS services
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamodb = new AWS.DynamoDB.DocumentClient();
const ses = new AWS.SES();

// Validation schema
const registrationSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  name: Joi.string().min(2).max(100).required(),
  company: Joi.string().max(100).optional(),
  industry: Joi.string().valid('education', 'retail', 'smb', 'other').optional(),
  role: Joi.string().max(100).optional(),
  interests: Joi.array().items(Joi.string()).optional(),
  referralSource: Joi.string().optional()
});

/**
 * Main registration handler
 */
exports.handler = async (event) => {
  console.log('Registration request received:', JSON.stringify(event, null, 2));
  
  try {
    // Parse and validate request body
    const body = JSON.parse(event.body || '{}');
    const { error, value: validatedData } = registrationSchema.validate(body);
    
    if (error) {
      return createResponse(400, {
        error: 'Validation failed',
        details: error.details.map(detail => detail.message)
      });
    }

    const { email, password, name, company, industry, role, interests, referralSource } = validatedData;

    // Check if user already exists
    const existingUser = await checkExistingUser(email);
    if (existingUser) {
      return createResponse(409, {
        error: 'User already exists',
        message: 'An account with this email already exists'
      });
    }

    // Create user in Cognito
    const cognitoUser = await createCognitoUser({
      email,
      password,
      name,
      company,
      industry
    });

    // Create user profile in DynamoDB
    const userProfile = await createUserProfile({
      userId: cognitoUser.User.Username,
      email,
      name,
      company,
      industry,
      role,
      interests,
      referralSource
    });

    // Send welcome email with industry-specific content
    await sendWelcomeEmail({
      email,
      name,
      industry,
      userId: cognitoUser.User.Username
    });

    // Track registration for competitive intelligence
    await trackRegistration({
      userId: cognitoUser.User.Username,
      industry,
      referralSource,
      timestamp: new Date().toISOString()
    });

    return createResponse(201, {
      message: 'User registered successfully',
      userId: cognitoUser.User.Username,
      nextSteps: getIndustrySpecificNextSteps(industry)
    });

  } catch (error) {
    console.error('Registration error:', error);
    
    return createResponse(500, {
      error: 'Registration failed',
      message: error.message || 'Internal server error'
    });
  }
};

/**
 * Check if user already exists in Cognito
 */
async function checkExistingUser(email) {
  try {
    await cognito.adminGetUser({
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: email
    }).promise();
    
    return true; // User exists
  } catch (error) {
    if (error.code === 'UserNotFoundException') {
      return false; // User doesn't exist
    }
    throw error; // Other error
  }
}

/**
 * Create user in Cognito User Pool
 */
async function createCognitoUser({ email, password, name, company, industry }) {
  const userAttributes = [
    { Name: 'email', Value: email },
    { Name: 'name', Value: name },
    { Name: 'email_verified', Value: 'true' }
  ];

  if (company) {
    userAttributes.push({ Name: 'custom:company', Value: company });
  }

  if (industry) {
    userAttributes.push({ Name: 'custom:industry', Value: industry });
  }

  const cognitoParams = {
    UserPoolId: process.env.COGNITO_USER_POOL_ID,
    Username: email,
    TemporaryPassword: password,
    MessageAction: 'SUPPRESS', // Don't send welcome email from Cognito
    UserAttributes: userAttributes
  };

  const cognitoUser = await cognito.adminCreateUser(cognitoParams).promise();

  // Set permanent password
  await cognito.adminSetUserPassword({
    UserPoolId: process.env.COGNITO_USER_POOL_ID,
    Username: email,
    Password: password,
    Permanent: true
  }).promise();

  return cognitoUser;
}

/**
 * Create user profile in DynamoDB
 */
async function createUserProfile({
  userId,
  email,
  name,
  company,
  industry,
  role,
  interests,
  referralSource
}) {
  const profileData = {
    userId,
    email,
    name,
    company: company || '',
    industry: industry || 'other',
    role: role || '',
    interests: interests || [],
    referralSource: referralSource || 'direct',
    createdAt: new Date().toISOString(),
    lastLoginAt: null,
    profileCompleteness: calculateProfileCompleteness({
      name, company, industry, role, interests
    }),
    preferences: {
      emailNotifications: true,
      industryUpdates: true,
      learningRecommendations: true
    },
    subscriptions: [],
    achievements: [],
    learningProgress: {
      coursesCompleted: 0,
      certificationsEarned: 0,
      labsCompleted: 0,
      skillScore: 0
    },
    competitiveAdvantages: getIndustryCompetitiveAdvantages(industry)
  };

  await dynamodb.put({
    TableName: process.env.DYNAMODB_TABLE,
    Item: profileData
  }).promise();

  return profileData;
}

/**
 * Send industry-specific welcome email
 */
async function sendWelcomeEmail({ email, name, industry, userId }) {
  const industryContent = getIndustryWelcomeContent(industry);
  
  const emailParams = {
    Source: 'welcome@cloudnestle.com',
    Destination: {
      ToAddresses: [email]
    },
    Message: {
      Subject: {
        Data: `Welcome to CloudNestle, ${name}! 🚀`,
        Charset: 'UTF-8'
      },
      Body: {
        Html: {
          Data: generateWelcomeEmailHTML({
            name,
            industry,
            industryContent,
            userId
          }),
          Charset: 'UTF-8'
        },
        Text: {
          Data: generateWelcomeEmailText({
            name,
            industry,
            industryContent
          }),
          Charset: 'UTF-8'
        }
      }
    }
  };

  try {
    await ses.sendEmail(emailParams).promise();
    console.log(`Welcome email sent to ${email}`);
  } catch (error) {
    console.error('Failed to send welcome email:', error);
    // Don't fail registration if email fails
  }
}

/**
 * Track registration for competitive intelligence
 */
async function trackRegistration({ userId, industry, referralSource, timestamp }) {
  // Store registration analytics
  const analyticsData = {
    eventType: 'user_registration',
    userId,
    industry,
    referralSource,
    timestamp,
    metadata: {
      stage: process.env.STAGE,
      userAgent: 'backend-registration'
    }
  };

  // Store in analytics table (would be created separately)
  try {
    await dynamodb.put({
      TableName: `cloudnestle-analytics-${process.env.STAGE}`,
      Item: {
        eventId: uuidv4(),
        ...analyticsData
      }
    }).promise();
  } catch (error) {
    console.error('Failed to track registration:', error);
    // Don't fail registration if analytics fail
  }
}

/**
 * Calculate profile completeness percentage
 */
function calculateProfileCompleteness({ name, company, industry, role, interests }) {
  let completeness = 0;
  const fields = [
    { field: name, weight: 20 },
    { field: company, weight: 20 },
    { field: industry, weight: 20 },
    { field: role, weight: 20 },
    { field: interests && interests.length > 0, weight: 20 }
  ];

  fields.forEach(({ field, weight }) => {
    if (field) completeness += weight;
  });

  return completeness;
}

/**
 * Get industry-specific competitive advantages
 */
function getIndustryCompetitiveAdvantages(industry) {
  const advantages = {
    education: [
      'FERPA/COPPA compliance expertise',
      'EdTech solution architecture',
      'Student data privacy frameworks',
      'Learning analytics implementation'
    ],
    retail: [
      'E-commerce platform optimization',
      'Omnichannel experience design',
      'Supply chain integration',
      'Customer personalization engines'
    ],
    smb: [
      'Cost-effective migration strategies',
      'Simplified implementation processes',
      'Growth-ready architectures',
      'Budget-conscious optimization'
    ],
    other: [
      'AWS Well-Architected expertise',
      'Security best practices',
      'Cost optimization strategies',
      'Performance optimization'
    ]
  };

  return advantages[industry] || advantages.other;
}

/**
 * Get industry-specific next steps
 */
function getIndustrySpecificNextSteps(industry) {
  const nextSteps = {
    education: [
      'Complete your Education Sector Assessment',
      'Join the Education User Group',
      'Explore FERPA compliance resources',
      'Schedule a compliance consultation'
    ],
    retail: [
      'Take the Retail Readiness Assessment',
      'Join the Retail Technology Leaders group',
      'Explore e-commerce architecture patterns',
      'Book an omnichannel strategy session'
    ],
    smb: [
      'Complete the SMB Cloud Assessment',
      'Join the SMB Accelerator program',
      'Access cost optimization tools',
      'Schedule a budget planning session'
    ],
    other: [
      'Complete the AWS Readiness Assessment',
      'Explore our learning paths',
      'Join the general community',
      'Schedule an architecture review'
    ]
  };

  return nextSteps[industry] || nextSteps.other;
}

/**
 * Get industry-specific welcome content
 */
function getIndustryWelcomeContent(industry) {
  const content = {
    education: {
      title: 'Welcome to Education Cloud Excellence',
      description: 'Join 2,000+ education professionals transforming learning with AWS',
      benefits: [
        'FERPA/COPPA compliance expertise',
        'Student data privacy frameworks',
        'EdTech solution patterns',
        'Learning analytics implementation'
      ]
    },
    retail: {
      title: 'Welcome to Retail Innovation Hub',
      description: 'Join 1,500+ retail leaders building the future of commerce',
      benefits: [
        'E-commerce platform optimization',
        'Omnichannel experience design',
        'Supply chain modernization',
        'Customer personalization engines'
      ]
    },
    smb: {
      title: 'Welcome to SMB Cloud Acceleration',
      description: 'Join 3,000+ SMB leaders scaling with cost-effective cloud solutions',
      benefits: [
        'Budget-conscious migration strategies',
        'Simplified implementation processes',
        'Growth-ready architectures',
        'Ongoing managed services'
      ]
    },
    other: {
      title: 'Welcome to CloudNestle Community',
      description: 'Join 10,000+ AWS professionals advancing their cloud expertise',
      benefits: [
        'Industry-specific expertise',
        'AI-powered recommendations',
        'Outcome guarantees',
        'Community learning platform'
      ]
    }
  };

  return content[industry] || content.other;
}

/**
 * Generate HTML welcome email
 */
function generateWelcomeEmailHTML({ name, industry, industryContent, userId }) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Welcome to CloudNestle</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #FF9900;">Welcome to CloudNestle, ${name}! 🚀</h1>
            </div>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #232F3E;">${industryContent.title}</h2>
                <p>${industryContent.description}</p>
            </div>
            
            <h3>Your Competitive Advantages:</h3>
            <ul>
                ${industryContent.benefits.map(benefit => `<li>${benefit}</li>`).join('')}
            </ul>
            
            <div style="background: #e8f4fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <h3>🎯 Next Steps:</h3>
                <ol>
                    <li><a href="https://cloudnestle.com/auth-academy-dashboard.html">Complete your profile</a></li>
                    <li><a href="https://cloudnestle.com/reg-${industry}-assessment.html">Take your industry assessment</a></li>
                    <li><a href="https://cloudnestle.com/community/${industry}-user-group.html">Join your industry user group</a></li>
                    <li><a href="https://cloudnestle.com/auth-consultation-booking.html">Schedule expert consultation</a></li>
                </ol>
            </div>
            
            <div style="text-align: center; margin-top: 30px;">
                <a href="https://cloudnestle.com/auth-academy-dashboard.html" 
                   style="background: #FF9900; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                    Access Your Dashboard
                </a>
            </div>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 14px; color: #666;">
                <p>Questions? Reply to this email or visit our <a href="https://cloudnestle.com/help">Help Center</a></p>
                <p>CloudNestle - The Unbeatable AWS Specialist</p>
            </div>
        </div>
    </body>
    </html>
  `;
}

/**
 * Generate text welcome email
 */
function generateWelcomeEmailText({ name, industry, industryContent }) {
  return `
Welcome to CloudNestle, ${name}!

${industryContent.title}
${industryContent.description}

Your Competitive Advantages:
${industryContent.benefits.map(benefit => `• ${benefit}`).join('\n')}

Next Steps:
1. Complete your profile: https://cloudnestle.com/auth-academy-dashboard.html
2. Take your industry assessment: https://cloudnestle.com/reg-${industry}-assessment.html
3. Join your industry user group: https://cloudnestle.com/community/${industry}-user-group.html
4. Schedule expert consultation: https://cloudnestle.com/auth-consultation-booking.html

Access Your Dashboard: https://cloudnestle.com/auth-academy-dashboard.html

Questions? Reply to this email or visit our Help Center: https://cloudnestle.com/help

CloudNestle - The Unbeatable AWS Specialist
  `;
}

/**
 * Create standardized API response
 */
function createResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  };
}
