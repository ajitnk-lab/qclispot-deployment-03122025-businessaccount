const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const bedrock = new AWS.BedrockRuntime();

// AI-powered recommendation engine
exports.handler = async (event) => {
  try {
    // Extract user information from JWT token
    const userId = event.requestContext.authorizer.claims.sub;
    const userEmail = event.requestContext.authorizer.claims.email;
    
    // Get query parameters
    const { type, industry, companySize, currentState } = event.queryStringParameters || {};
    
    // Get user profile for personalization
    let userProfile = {};
    try {
      const profileResult = await dynamodb.get({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { userId }
      }).promise();
      
      if (profileResult.Item) {
        userProfile = profileResult.Item;
      }
    } catch (error) {
      console.log('Could not fetch user profile:', error);
    }
    
    // Generate recommendations based on type
    let recommendations = [];
    
    switch (type) {
      case 'architecture':
        recommendations = await generateArchitectureRecommendations(userProfile, { industry, companySize, currentState });
        break;
      case 'learning':
        recommendations = await generateLearningRecommendations(userProfile, { industry, companySize });
        break;
      case 'solutions':
        recommendations = await generateSolutionRecommendations(userProfile, { industry, companySize, currentState });
        break;
      case 'frameworks':
        recommendations = await generateFrameworkRecommendations(userProfile, { industry, companySize, currentState });
        break;
      default:
        recommendations = await generateGeneralRecommendations(userProfile, { industry, companySize, currentState });
    }
    
    // Log recommendation request for analytics
    await logRecommendationRequest(userId, type, recommendations.length);
    
    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'GET'
      },
      body: JSON.stringify({
        recommendations,
        personalized: Object.keys(userProfile).length > 0,
        timestamp: new Date().toISOString()
      })
    };
    
  } catch (error) {
    console.error('Recommendations error:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Failed to generate recommendations',
        message: error.message
      })
    };
  }
};

// Generate architecture recommendations
async function generateArchitectureRecommendations(userProfile, context) {
  const { industry, companySize, currentState } = context;
  
  const recommendations = [];
  
  // Industry-specific architecture recommendations
  if (industry === 'education') {
    recommendations.push({
      id: 'edu-learning-platform',
      title: 'Scalable Learning Management Architecture',
      description: 'Serverless architecture optimized for educational workloads with FERPA compliance',
      priority: 'high',
      estimatedImpact: 'High cost savings and improved performance',
      services: ['Lambda', 'DynamoDB', 'CloudFront', 'Cognito'],
      timeline: '3-6 months',
      complexity: 'medium'
    });
    
    recommendations.push({
      id: 'edu-analytics-platform',
      title: 'Student Analytics and Insights Platform',
      description: 'Real-time analytics platform for student performance and engagement tracking',
      priority: 'medium',
      estimatedImpact: 'Improved student outcomes and operational insights',
      services: ['Kinesis', 'QuickSight', 'Redshift', 'SageMaker'],
      timeline: '4-8 months',
      complexity: 'high'
    });
  }
  
  if (industry === 'retail') {
    recommendations.push({
      id: 'retail-ecommerce-platform',
      title: 'High-Performance E-commerce Architecture',
      description: 'Scalable e-commerce platform with global CDN and real-time inventory',
      priority: 'high',
      estimatedImpact: 'Increased sales and reduced cart abandonment',
      services: ['ECS', 'RDS', 'ElastiCache', 'CloudFront'],
      timeline: '4-8 months',
      complexity: 'high'
    });
    
    recommendations.push({
      id: 'retail-personalization',
      title: 'AI-Powered Personalization Engine',
      description: 'Machine learning-based recommendation system for personalized shopping',
      priority: 'medium',
      estimatedImpact: 'Higher conversion rates and customer satisfaction',
      services: ['Personalize', 'SageMaker', 'Kinesis', 'DynamoDB'],
      timeline: '6-12 months',
      complexity: 'high'
    });
  }
  
  // Company size-specific recommendations
  if (companySize === 'startup') {
    recommendations.push({
      id: 'startup-serverless-foundation',
      title: 'Cost-Optimized Serverless Foundation',
      description: 'Pay-per-use serverless architecture that scales with your growth',
      priority: 'high',
      estimatedImpact: '60-80% cost savings compared to traditional infrastructure',
      services: ['Lambda', 'API Gateway', 'DynamoDB', 'S3'],
      timeline: '1-3 months',
      complexity: 'low'
    });
  }
  
  if (companySize === 'enterprise') {
    recommendations.push({
      id: 'enterprise-multi-account',
      title: 'Multi-Account Governance Architecture',
      description: 'Enterprise-grade multi-account setup with centralized governance',
      priority: 'high',
      estimatedImpact: 'Improved security, compliance, and cost management',
      services: ['Organizations', 'Control Tower', 'Config', 'CloudTrail'],
      timeline: '6-12 months',
      complexity: 'high'
    });
  }
  
  return recommendations;
}

// Generate learning path recommendations
async function generateLearningRecommendations(userProfile, context) {
  const { industry, companySize } = context;
  
  const recommendations = [];
  
  // Role-based learning paths
  const userRole = userProfile.role || 'developer';
  
  if (userRole.includes('architect') || userRole.includes('senior')) {
    recommendations.push({
      id: 'solutions-architect-path',
      title: 'AWS Solutions Architect Professional',
      description: 'Advanced certification path for designing distributed systems on AWS',
      priority: 'high',
      duration: '3-6 months',
      prerequisites: ['Solutions Architect Associate'],
      modules: [
        'Advanced Networking',
        'Security and Compliance',
        'Cost Optimization',
        'Migration Strategies'
      ]
    });
  }
  
  if (userRole.includes('developer') || userRole.includes('engineer')) {
    recommendations.push({
      id: 'developer-path',
      title: 'AWS Developer Associate',
      description: 'Comprehensive development skills for building applications on AWS',
      priority: 'high',
      duration: '2-4 months',
      prerequisites: ['Basic AWS knowledge'],
      modules: [
        'Serverless Development',
        'Container Services',
        'Database Integration',
        'Monitoring and Debugging'
      ]
    });
  }
  
  // Industry-specific learning
  if (industry === 'education') {
    recommendations.push({
      id: 'education-compliance-training',
      title: 'Education Compliance on AWS',
      description: 'FERPA, COPPA, and education-specific compliance requirements',
      priority: 'medium',
      duration: '1-2 months',
      prerequisites: ['Basic AWS Security'],
      modules: [
        'FERPA Compliance Framework',
        'Student Data Protection',
        'Audit and Reporting',
        'Privacy by Design'
      ]
    });
  }
  
  return recommendations;
}

// Generate solution recommendations
async function generateSolutionRecommendations(userProfile, context) {
  const { industry, companySize, currentState } = context;
  
  const recommendations = [];
  
  // AWS Solutions Library recommendations
  if (industry === 'education') {
    recommendations.push({
      id: 'aws-education-solutions',
      title: 'AWS for Education Solutions',
      description: 'Pre-built solutions for common education use cases',
      category: 'AWS Solutions',
      solutions: [
        'Virtual Desktop Infrastructure for Students',
        'Learning Analytics Platform',
        'Campus Wi-Fi and IoT Management',
        'Research Computing Platform'
      ],
      implementationTime: '2-6 months',
      complexity: 'medium'
    });
  }
  
  if (companySize === 'startup') {
    recommendations.push({
      id: 'startup-accelerator-solutions',
      title: 'Startup Solution Accelerators',
      description: 'Quick-deploy solutions for common startup needs',
      category: 'Solution Accelerators',
      solutions: [
        'MVP Development Platform',
        'User Authentication System',
        'Analytics and Monitoring Stack',
        'CI/CD Pipeline Template'
      ],
      implementationTime: '2-8 weeks',
      complexity: 'low'
    });
  }
  
  return recommendations;
}

// Generate framework recommendations
async function generateFrameworkRecommendations(userProfile, context) {
  const { industry, companySize, currentState } = context;
  
  const recommendations = [];
  
  // Always recommend CAF assessment for new users
  if (!userProfile.assessments || !userProfile.assessments.caf) {
    recommendations.push({
      id: 'caf-assessment',
      title: 'Cloud Adoption Framework Assessment',
      description: 'Comprehensive assessment of your cloud readiness across 6 perspectives',
      framework: 'CAF',
      priority: 'high',
      duration: '2-4 weeks',
      outcome: 'Detailed roadmap for cloud adoption',
      nextSteps: ['Well-Architected Review', 'Security Maturity Assessment']
    });
  }
  
  // Well-Architected recommendations based on current state
  if (currentState === 'migrated' || currentState === 'optimizing') {
    recommendations.push({
      id: 'well-architected-review',
      title: 'Well-Architected Framework Review',
      description: 'Comprehensive architecture review across 6 pillars',
      framework: 'Well-Architected',
      priority: 'high',
      duration: '1-3 weeks',
      outcome: 'Architecture optimization recommendations',
      pillars: [
        'Operational Excellence',
        'Security',
        'Reliability',
        'Performance Efficiency',
        'Cost Optimization',
        'Sustainability'
      ]
    });
  }
  
  return recommendations;
}

// Generate general recommendations
async function generateGeneralRecommendations(userProfile, context) {
  const recommendations = [];
  
  // Default recommendations for new users
  recommendations.push({
    id: 'getting-started',
    title: 'AWS Cloud Transformation Getting Started',
    description: 'Comprehensive guide to beginning your cloud journey',
    type: 'guide',
    priority: 'high',
    steps: [
      'Complete Cloud Readiness Assessment',
      'Define Business Objectives',
      'Choose Migration Strategy',
      'Plan Implementation Timeline'
    ]
  });
  
  return recommendations;
}

// Log recommendation request for analytics
async function logRecommendationRequest(userId, type, count) {
  try {
    await dynamodb.put({
      TableName: process.env.ANALYTICS_TABLE || process.env.DYNAMODB_TABLE,
      Item: {
        id: `rec-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        userId,
        type: 'recommendation_request',
        recommendationType: type,
        recommendationCount: count,
        timestamp: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days TTL
      }
    }).promise();
  } catch (error) {
    console.log('Failed to log recommendation request:', error);
  }
}
