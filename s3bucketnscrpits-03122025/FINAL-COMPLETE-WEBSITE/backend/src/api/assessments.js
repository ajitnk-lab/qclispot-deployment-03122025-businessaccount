const AWS = require('aws-sdk');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const ses = new AWS.SES();

// Assessment handler for various assessment types
exports.handler = async (event) => {
  try {
    const { httpMethod, pathParameters, queryStringParameters } = event;
    const userId = event.requestContext.authorizer?.claims?.sub;
    
    switch (httpMethod) {
      case 'POST':
        return await createAssessment(event, userId);
      case 'GET':
        if (pathParameters && pathParameters.assessmentId) {
          return await getAssessment(pathParameters.assessmentId, userId);
        } else {
          return await listAssessments(queryStringParameters, userId);
        }
      case 'PUT':
        return await updateAssessment(event, userId);
      default:
        return {
          statusCode: 405,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
          },
          body: JSON.stringify({ error: 'Method not allowed' })
        };
    }
    
  } catch (error) {
    console.error('Assessment handler error:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message
      })
    };
  }
};

// Create new assessment
async function createAssessment(event, userId) {
  const assessmentData = JSON.parse(event.body);
  const { type, responses, metadata } = assessmentData;
  
  // Validate assessment type
  const validTypes = ['caf', 'well-architected', 'security-maturity', 'startup', 'industry-roi'];
  if (!validTypes.includes(type)) {
    return {
      statusCode: 400,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({
        error: 'Invalid assessment type',
        validTypes
      })
    };
  }
  
  const assessmentId = `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  // Calculate assessment score based on type
  const score = await calculateAssessmentScore(type, responses);
  
  // Generate recommendations based on assessment
  const recommendations = await generateAssessmentRecommendations(type, responses, score, metadata);
  
  // Create assessment record
  const assessment = {
    assessmentId,
    userId: userId || 'anonymous',
    type,
    responses,
    metadata: {
      ...metadata,
      userAgent: event.headers['User-Agent'],
      ipAddress: event.requestContext.identity.sourceIp,
      timestamp: new Date().toISOString()
    },
    score,
    recommendations,
    status: 'completed',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year TTL
  };
  
  // Save to DynamoDB
  await dynamodb.put({
    TableName: process.env.ASSESSMENTS_TABLE || process.env.DYNAMODB_TABLE,
    Item: assessment
  }).promise();
  
  // Send assessment results via email if email provided
  if (metadata.email) {
    await sendAssessmentResults(assessment, metadata.email);
  }
  
  // Log assessment completion for analytics
  await logAssessmentCompletion(assessmentId, type, score, userId);
  
  return {
    statusCode: 201,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    },
    body: JSON.stringify({
      assessmentId,
      score,
      recommendations,
      status: 'completed',
      message: 'Assessment completed successfully'
    })
  };
}

// Get assessment by ID
async function getAssessment(assessmentId, userId) {
  const result = await dynamodb.get({
    TableName: process.env.ASSESSMENTS_TABLE || process.env.DYNAMODB_TABLE,
    Key: { assessmentId }
  }).promise();
  
  if (!result.Item) {
    return {
      statusCode: 404,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({ error: 'Assessment not found' })
    };
  }
  
  // Check if user has access to this assessment
  if (result.Item.userId !== userId && result.Item.userId !== 'anonymous') {
    return {
      statusCode: 403,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({ error: 'Access denied' })
    };
  }
  
  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    },
    body: JSON.stringify(result.Item)
  };
}

// List assessments for user
async function listAssessments(queryParams, userId) {
  const { type, limit = 10, lastKey } = queryParams || {};
  
  let params = {
    TableName: process.env.ASSESSMENTS_TABLE || process.env.DYNAMODB_TABLE,
    IndexName: 'UserIdIndex',
    KeyConditionExpression: 'userId = :userId',
    ExpressionAttributeValues: {
      ':userId': userId
    },
    Limit: parseInt(limit),
    ScanIndexForward: false // Most recent first
  };
  
  if (type) {
    params.FilterExpression = '#type = :type';
    params.ExpressionAttributeNames = { '#type': 'type' };
    params.ExpressionAttributeValues[':type'] = type;
  }
  
  if (lastKey) {
    params.ExclusiveStartKey = JSON.parse(decodeURIComponent(lastKey));
  }
  
  const result = await dynamodb.query(params).promise();
  
  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    },
    body: JSON.stringify({
      assessments: result.Items,
      lastKey: result.LastEvaluatedKey ? encodeURIComponent(JSON.stringify(result.LastEvaluatedKey)) : null,
      count: result.Count
    })
  };
}

// Update assessment
async function updateAssessment(event, userId) {
  const { assessmentId } = event.pathParameters;
  const updateData = JSON.parse(event.body);
  
  // Get existing assessment
  const existing = await dynamodb.get({
    TableName: process.env.ASSESSMENTS_TABLE || process.env.DYNAMODB_TABLE,
    Key: { assessmentId }
  }).promise();
  
  if (!existing.Item) {
    return {
      statusCode: 404,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({ error: 'Assessment not found' })
    };
  }
  
  // Check access
  if (existing.Item.userId !== userId) {
    return {
      statusCode: 403,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      },
      body: JSON.stringify({ error: 'Access denied' })
    };
  }
  
  // Update assessment
  const updateParams = {
    TableName: process.env.ASSESSMENTS_TABLE || process.env.DYNAMODB_TABLE,
    Key: { assessmentId },
    UpdateExpression: 'SET updatedAt = :updatedAt',
    ExpressionAttributeValues: {
      ':updatedAt': new Date().toISOString()
    },
    ReturnValues: 'ALL_NEW'
  };
  
  // Add updateable fields
  const updateableFields = ['metadata', 'notes', 'status'];
  updateableFields.forEach(field => {
    if (updateData[field] !== undefined) {
      updateParams.UpdateExpression += `, ${field} = :${field}`;
      updateParams.ExpressionAttributeValues[`:${field}`] = updateData[field];
    }
  });
  
  const result = await dynamodb.update(updateParams).promise();
  
  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    },
    body: JSON.stringify(result.Attributes)
  };
}

// Calculate assessment score based on type and responses
async function calculateAssessmentScore(type, responses) {
  switch (type) {
    case 'caf':
      return calculateCAFScore(responses);
    case 'well-architected':
      return calculateWellArchitectedScore(responses);
    case 'security-maturity':
      return calculateSecurityMaturityScore(responses);
    case 'startup':
      return calculateStartupScore(responses);
    case 'industry-roi':
      return calculateROIScore(responses);
    default:
      return { overall: 0, breakdown: {} };
  }
}

// CAF assessment scoring
function calculateCAFScore(responses) {
  const perspectives = ['business', 'people', 'governance', 'platform', 'security', 'operations'];
  const breakdown = {};
  let totalScore = 0;
  
  perspectives.forEach(perspective => {
    const perspectiveResponses = responses.filter(r => r.perspective === perspective);
    const perspectiveScore = perspectiveResponses.reduce((sum, r) => sum + (r.score || 0), 0) / perspectiveResponses.length;
    breakdown[perspective] = Math.round(perspectiveScore * 10) / 10;
    totalScore += perspectiveScore;
  });
  
  return {
    overall: Math.round((totalScore / perspectives.length) * 10) / 10,
    breakdown,
    maturityLevel: getCAFMaturityLevel(totalScore / perspectives.length)
  };
}

// Well-Architected assessment scoring
function calculateWellArchitectedScore(responses) {
  const pillars = ['operational-excellence', 'security', 'reliability', 'performance-efficiency', 'cost-optimization', 'sustainability'];
  const breakdown = {};
  let totalScore = 0;
  
  pillars.forEach(pillar => {
    const pillarResponses = responses.filter(r => r.pillar === pillar);
    const pillarScore = pillarResponses.reduce((sum, r) => sum + (r.score || 0), 0) / pillarResponses.length;
    breakdown[pillar] = Math.round(pillarScore * 10) / 10;
    totalScore += pillarScore;
  });
  
  return {
    overall: Math.round((totalScore / pillars.length) * 10) / 10,
    breakdown,
    riskLevel: getWellArchitectedRiskLevel(totalScore / pillars.length)
  };
}

// Security maturity scoring
function calculateSecurityMaturityScore(responses) {
  const domains = ['identity', 'detective-controls', 'infrastructure-protection', 'data-protection', 'incident-response'];
  const breakdown = {};
  let totalScore = 0;
  
  domains.forEach(domain => {
    const domainResponses = responses.filter(r => r.domain === domain);
    const domainScore = domainResponses.reduce((sum, r) => sum + (r.score || 0), 0) / domainResponses.length;
    breakdown[domain] = Math.round(domainScore * 10) / 10;
    totalScore += domainScore;
  });
  
  const overallScore = totalScore / domains.length;
  
  return {
    overall: Math.round(overallScore * 10) / 10,
    breakdown,
    maturityPhase: getSecurityMaturityPhase(overallScore)
  };
}

// Startup assessment scoring
function calculateStartupScore(responses) {
  const areas = ['technical-readiness', 'scalability', 'security', 'cost-optimization', 'team-capability'];
  const breakdown = {};
  let totalScore = 0;
  
  areas.forEach(area => {
    const areaResponses = responses.filter(r => r.area === area);
    const areaScore = areaResponses.reduce((sum, r) => sum + (r.score || 0), 0) / areaResponses.length;
    breakdown[area] = Math.round(areaScore * 10) / 10;
    totalScore += areaScore;
  });
  
  return {
    overall: Math.round((totalScore / areas.length) * 10) / 10,
    breakdown,
    readinessLevel: getStartupReadinessLevel(totalScore / areas.length)
  };
}

// ROI assessment scoring
function calculateROIScore(responses) {
  const factors = ['current-costs', 'optimization-potential', 'growth-projections', 'implementation-complexity'];
  const breakdown = {};
  let totalScore = 0;
  
  factors.forEach(factor => {
    const factorResponses = responses.filter(r => r.factor === factor);
    const factorScore = factorResponses.reduce((sum, r) => sum + (r.score || 0), 0) / factorResponses.length;
    breakdown[factor] = Math.round(factorScore * 10) / 10;
    totalScore += factorScore;
  });
  
  return {
    overall: Math.round((totalScore / factors.length) * 10) / 10,
    breakdown,
    roiProjection: calculateROIProjection(breakdown)
  };
}

// Generate recommendations based on assessment results
async function generateAssessmentRecommendations(type, responses, score, metadata) {
  const recommendations = [];
  
  switch (type) {
    case 'caf':
      recommendations.push(...generateCAFRecommendations(score, responses, metadata));
      break;
    case 'well-architected':
      recommendations.push(...generateWellArchitectedRecommendations(score, responses, metadata));
      break;
    case 'security-maturity':
      recommendations.push(...generateSecurityRecommendations(score, responses, metadata));
      break;
    case 'startup':
      recommendations.push(...generateStartupRecommendations(score, responses, metadata));
      break;
    case 'industry-roi':
      recommendations.push(...generateROIRecommendations(score, responses, metadata));
      break;
  }
  
  return recommendations;
}

// Generate CAF-specific recommendations
function generateCAFRecommendations(score, responses, metadata) {
  const recommendations = [];
  
  // Analyze lowest scoring perspectives
  const sortedPerspectives = Object.entries(score.breakdown)
    .sort(([,a], [,b]) => a - b)
    .slice(0, 3);
  
  sortedPerspectives.forEach(([perspective, perspectiveScore]) => {
    if (perspectiveScore < 7) {
      recommendations.push({
        id: `caf-${perspective}-improvement`,
        title: `Improve ${perspective.charAt(0).toUpperCase() + perspective.slice(1)} Perspective`,
        description: `Focus on strengthening your ${perspective} capabilities to improve overall cloud readiness.`,
        priority: perspectiveScore < 5 ? 'high' : 'medium',
        category: 'caf-perspective',
        perspective,
        estimatedImpact: 'High',
        timeline: '2-6 months',
        resources: [
          `CAF ${perspective} perspective guide`,
          `${perspective} capability assessment`,
          `Implementation roadmap for ${perspective}`
        ]
      });
    }
  });
  
  return recommendations;
}

// Generate Well-Architected recommendations
function generateWellArchitectedRecommendations(score, responses, metadata) {
  const recommendations = [];
  
  // Focus on highest risk pillars
  const sortedPillars = Object.entries(score.breakdown)
    .sort(([,a], [,b]) => a - b)
    .slice(0, 3);
  
  sortedPillars.forEach(([pillar, pillarScore]) => {
    if (pillarScore < 7) {
      recommendations.push({
        id: `wa-${pillar}-improvement`,
        title: `Address ${pillar.replace('-', ' ')} Issues`,
        description: `Implement best practices to improve your ${pillar.replace('-', ' ')} posture.`,
        priority: pillarScore < 5 ? 'high' : 'medium',
        category: 'well-architected-pillar',
        pillar,
        estimatedImpact: pillarScore < 5 ? 'High' : 'Medium',
        timeline: '1-4 months',
        resources: [
          `${pillar} pillar whitepaper`,
          `${pillar} best practices guide`,
          `Implementation checklist for ${pillar}`
        ]
      });
    }
  });
  
  return recommendations;
}

// Generate startup-specific recommendations
function generateStartupRecommendations(score, responses, metadata) {
  const recommendations = [];
  
  // Startup-specific recommendations based on stage and industry
  const { startupStage, industry, teamSize } = metadata;
  
  if (score.overall < 6) {
    recommendations.push({
      id: 'startup-foundation-setup',
      title: 'Establish Cloud Foundation',
      description: 'Set up essential cloud infrastructure with startup-optimized configurations.',
      priority: 'high',
      category: 'foundation',
      estimatedImpact: 'High - Enables rapid scaling',
      timeline: '2-4 weeks',
      estimatedCost: '$500-2000/month',
      resources: [
        'Startup cloud foundation template',
        'Cost optimization guide for startups',
        'Security best practices for early-stage companies'
      ]
    });
  }
  
  if (startupStage === 'growth' || startupStage === 'scaling') {
    recommendations.push({
      id: 'startup-scaling-preparation',
      title: 'Prepare for Scale',
      description: 'Implement auto-scaling and performance optimization for rapid growth.',
      priority: 'high',
      category: 'scaling',
      estimatedImpact: 'High - Supports 10x+ growth',
      timeline: '4-8 weeks',
      resources: [
        'Auto-scaling configuration guide',
        'Performance optimization checklist',
        'Database scaling strategies'
      ]
    });
  }
  
  return recommendations;
}

// Send assessment results via email
async function sendAssessmentResults(assessment, email) {
  const { type, score, recommendations } = assessment;
  
  const emailParams = {
    Source: process.env.FROM_EMAIL || 'noreply@cloudnestle.com',
    Destination: {
      ToAddresses: [email]
    },
    Message: {
      Subject: {
        Data: `Your ${type.toUpperCase()} Assessment Results - CloudNestle`
      },
      Body: {
        Html: {
          Data: generateAssessmentEmailHTML(assessment)
        },
        Text: {
          Data: generateAssessmentEmailText(assessment)
        }
      }
    }
  };
  
  try {
    await ses.sendEmail(emailParams).promise();
    console.log('Assessment results email sent successfully');
  } catch (error) {
    console.error('Failed to send assessment results email:', error);
  }
}

// Generate HTML email content
function generateAssessmentEmailHTML(assessment) {
  const { type, score, recommendations } = assessment;
  
  return `
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #232F3E;">Your ${type.toUpperCase()} Assessment Results</h1>
          
          <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h2>Overall Score: ${score.overall}/10</h2>
            <p>Congratulations on completing your assessment! Here's a summary of your results.</p>
          </div>
          
          <h3>Top Recommendations:</h3>
          <ul>
            ${recommendations.slice(0, 3).map(rec => `
              <li style="margin-bottom: 10px;">
                <strong>${rec.title}</strong><br>
                ${rec.description}
              </li>
            `).join('')}
          </ul>
          
          <div style="background: #e8f4fd; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p><strong>Next Steps:</strong></p>
            <p>Schedule a free consultation with our experts to discuss your results and create an implementation plan.</p>
            <a href="https://cloudnestle.com/contact" style="background: #FF9900; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;">Schedule Consultation</a>
          </div>
          
          <p style="font-size: 12px; color: #666; margin-top: 30px;">
            This assessment was generated by CloudNestle's AI-powered analysis engine. 
            For questions, contact us at info@cloudnestle.com
          </p>
        </div>
      </body>
    </html>
  `;
}

// Generate text email content
function generateAssessmentEmailText(assessment) {
  const { type, score, recommendations } = assessment;
  
  return `
Your ${type.toUpperCase()} Assessment Results

Overall Score: ${score.overall}/10

Top Recommendations:
${recommendations.slice(0, 3).map((rec, i) => `${i + 1}. ${rec.title}: ${rec.description}`).join('\n')}

Next Steps:
Schedule a free consultation with our experts to discuss your results and create an implementation plan.

Visit: https://cloudnestle.com/contact

Questions? Contact us at info@cloudnestle.com
  `;
}

// Log assessment completion for analytics
async function logAssessmentCompletion(assessmentId, type, score, userId) {
  try {
    await dynamodb.put({
      TableName: process.env.ANALYTICS_TABLE || process.env.DYNAMODB_TABLE,
      Item: {
        id: `assessment-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: 'assessment_completion',
        assessmentId,
        assessmentType: type,
        userId: userId || 'anonymous',
        score: score.overall,
        timestamp: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days TTL
      }
    }).promise();
  } catch (error) {
    console.log('Failed to log assessment completion:', error);
  }
}

// Helper functions for maturity levels
function getCAFMaturityLevel(score) {
  if (score >= 8) return 'Advanced';
  if (score >= 6) return 'Intermediate';
  if (score >= 4) return 'Basic';
  return 'Initial';
}

function getWellArchitectedRiskLevel(score) {
  if (score >= 8) return 'Low Risk';
  if (score >= 6) return 'Medium Risk';
  if (score >= 4) return 'High Risk';
  return 'Critical Risk';
}

function getSecurityMaturityPhase(score) {
  if (score >= 8) return 'Run';
  if (score >= 5) return 'Walk';
  return 'Crawl';
}

function getStartupReadinessLevel(score) {
  if (score >= 8) return 'Scale Ready';
  if (score >= 6) return 'Growth Ready';
  if (score >= 4) return 'MVP Ready';
  return 'Foundation Needed';
}

function calculateROIProjection(breakdown) {
  // Simplified ROI calculation based on breakdown scores
  const optimizationPotential = breakdown['optimization-potential'] || 5;
  const currentCosts = breakdown['current-costs'] || 5;
  const complexity = breakdown['implementation-complexity'] || 5;
  
  const projectedSavings = (optimizationPotential / 10) * 0.6; // Up to 60% savings
  const implementationRisk = (10 - complexity) / 10; // Lower complexity = lower risk
  
  return {
    projectedROI: Math.round((projectedSavings * implementationRisk * 400)), // Percentage
    paybackPeriod: Math.max(6, Math.round(18 - (optimizationPotential * 1.2))), // Months
    confidenceLevel: Math.round(implementationRisk * 100) // Percentage
  };
}
