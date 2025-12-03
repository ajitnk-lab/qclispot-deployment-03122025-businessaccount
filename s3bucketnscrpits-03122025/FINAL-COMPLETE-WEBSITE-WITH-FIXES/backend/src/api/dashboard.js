const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const cloudwatch = new AWS.CloudWatch();
const costexplorer = new AWS.CostExplorer();

// Environment variables
const JWT_SECRET = process.env.JWT_SECRET || 'cloudnestle-secret-key';
const USERS_TABLE = process.env.USERS_TABLE || 'cloudnestle-users';
const PROJECTS_TABLE = process.env.PROJECTS_TABLE || 'cloudnestle-projects';
const METRICS_TABLE = process.env.METRICS_TABLE || 'cloudnestle-metrics';

/**
 * Verify JWT token and extract user information
 */
function verifyToken(token) {
    try {
        return jwt.verify(token, JWT_SECRET);
    } catch (error) {
        throw new Error('Invalid token');
    }
}

/**
 * Get user dashboard overview data
 */
exports.getDashboardOverview = async (event) => {
    try {
        // Extract token from Authorization header
        const token = event.headers.Authorization?.replace('Bearer ', '');
        if (!token) {
            return {
                statusCode: 401,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({ error: 'No token provided' })
            };
        }

        const user = verifyToken(token);
        
        // Get user's projects
        const projectsResult = await dynamodb.query({
            TableName: PROJECTS_TABLE,
            IndexName: 'UserIdIndex',
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': user.userId
            }
        }).promise();

        // Get user's metrics
        const metricsResult = await dynamodb.query({
            TableName: METRICS_TABLE,
            IndexName: 'UserIdIndex',
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': user.userId
            },
            ScanIndexForward: false,
            Limit: 30 // Last 30 days
        }).promise();

        // Calculate overview statistics
        const projects = projectsResult.Items || [];
        const metrics = metricsResult.Items || [];
        
        const activeProjects = projects.filter(p => p.status === 'active').length;
        const completedProjects = projects.filter(p => p.status === 'completed').length;
        const totalBudget = projects.reduce((sum, p) => sum + (p.budget || 0), 0);
        const usedBudget = projects.reduce((sum, p) => sum + (p.spentBudget || 0), 0);

        // Get recent AWS cost data
        const endDate = new Date().toISOString().split('T')[0];
        const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        
        let costData = null;
        try {
            const costResult = await costexplorer.getCostAndUsage({
                TimePeriod: {
                    Start: startDate,
                    End: endDate
                },
                Granularity: 'DAILY',
                Metrics: ['UnblendedCost'],
                GroupBy: [{
                    Type: 'DIMENSION',
                    Key: 'SERVICE'
                }]
            }).promise();
            
            costData = costResult.ResultsByTime;
        } catch (costError) {
            console.log('Cost Explorer access limited:', costError.message);
        }

        const overview = {
            projects: {
                active: activeProjects,
                completed: completedProjects,
                total: projects.length
            },
            budget: {
                total: totalBudget,
                used: usedBudget,
                remaining: totalBudget - usedBudget,
                utilization: totalBudget > 0 ? (usedBudget / totalBudget * 100).toFixed(1) : 0
            },
            metrics: {
                totalAssessments: metrics.filter(m => m.type === 'assessment').length,
                avgScore: calculateAverageScore(metrics),
                lastActivity: metrics.length > 0 ? metrics[0].timestamp : null
            },
            costData: costData ? processCostData(costData) : null,
            recentActivity: getRecentActivity(projects, metrics)
        };

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify(overview)
        };

    } catch (error) {
        console.error('Dashboard overview error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};

/**
 * Get user's project management data
 */
exports.getProjectManagement = async (event) => {
    try {
        const token = event.headers.Authorization?.replace('Bearer ', '');
        if (!token) {
            return {
                statusCode: 401,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({ error: 'No token provided' })
            };
        }

        const user = verifyToken(token);
        
        // Get detailed project information
        const projectsResult = await dynamodb.query({
            TableName: PROJECTS_TABLE,
            IndexName: 'UserIdIndex',
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': user.userId
            }
        }).promise();

        const projects = projectsResult.Items || [];
        
        // Enrich projects with additional data
        const enrichedProjects = projects.map(project => ({
            ...project,
            progress: calculateProjectProgress(project),
            healthStatus: calculateProjectHealth(project),
            upcomingMilestones: getUpcomingMilestones(project),
            teamMembers: project.teamMembers || [],
            riskFactors: assessProjectRisks(project)
        }));

        // Calculate team utilization
        const teamUtilization = calculateTeamUtilization(enrichedProjects);
        
        // Get milestone timeline
        const milestoneTimeline = getMilestoneTimeline(enrichedProjects);

        const projectManagement = {
            projects: enrichedProjects,
            summary: {
                totalProjects: projects.length,
                activeProjects: projects.filter(p => p.status === 'active').length,
                onTrackProjects: enrichedProjects.filter(p => p.healthStatus === 'on-track').length,
                atRiskProjects: enrichedProjects.filter(p => p.healthStatus === 'at-risk').length,
                totalBudget: projects.reduce((sum, p) => sum + (p.budget || 0), 0),
                usedBudget: projects.reduce((sum, p) => sum + (p.spentBudget || 0), 0)
            },
            teamUtilization,
            milestoneTimeline,
            upcomingDeadlines: getUpcomingDeadlines(enrichedProjects)
        };

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify(projectManagement)
        };

    } catch (error) {
        console.error('Project management error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};

/**
 * Get performance monitoring data
 */
exports.getPerformanceMonitoring = async (event) => {
    try {
        const token = event.headers.Authorization?.replace('Bearer ', '');
        if (!token) {
            return {
                statusCode: 401,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({ error: 'No token provided' })
            };
        }

        const user = verifyToken(token);
        const timeRange = event.queryStringParameters?.timeRange || '1h';
        
        // Get CloudWatch metrics for user's resources
        const endTime = new Date();
        const startTime = new Date(endTime.getTime() - getTimeRangeMs(timeRange));
        
        // Simulate performance metrics (in production, this would query actual CloudWatch metrics)
        const performanceData = {
            systemHealth: {
                status: 'healthy',
                uptime: 99.95,
                lastIncident: null
            },
            applicationMetrics: {
                responseTime: {
                    current: 245,
                    trend: -15,
                    p95: 580,
                    p99: 1200
                },
                throughput: {
                    current: 1247,
                    trend: 8,
                    unit: 'req/min'
                },
                errorRate: {
                    current: 0.12,
                    trend: -0.05,
                    unit: '%'
                }
            },
            infrastructureMetrics: {
                cpu: {
                    utilization: 68,
                    trend: 5
                },
                memory: {
                    utilization: 72,
                    trend: -2
                },
                network: {
                    throughput: 1.2,
                    unit: 'GB/h'
                }
            },
            databaseMetrics: {
                queryTime: {
                    average: 12,
                    trend: -3,
                    unit: 'ms'
                },
                connections: {
                    active: 45,
                    max: 100
                },
                cacheHitRate: {
                    current: 94.2,
                    trend: 1.5
                }
            },
            alerts: [
                {
                    id: 'alert-001',
                    type: 'warning',
                    title: 'High CPU Utilization',
                    description: 'EC2 instance i-0123456789abcdef0 has been running at >80% CPU for 15 minutes',
                    timestamp: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
                    service: 'EC2',
                    severity: 'warning'
                },
                {
                    id: 'alert-002',
                    type: 'info',
                    title: 'Scheduled Maintenance',
                    description: 'RDS maintenance window scheduled for tonight 2:00 AM - 4:00 AM EST',
                    timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
                    service: 'RDS',
                    severity: 'info'
                }
            ],
            recommendations: [
                {
                    id: 'rec-001',
                    priority: 'high',
                    title: 'Enable Auto Scaling',
                    description: 'Configure auto scaling for your web tier to handle traffic spikes more efficiently',
                    expectedImpact: '30% better response time during peak hours',
                    estimatedEffort: '2-4 hours'
                },
                {
                    id: 'rec-002',
                    priority: 'medium',
                    title: 'Optimize Database Queries',
                    description: '3 slow queries identified that could benefit from indexing or query optimization',
                    expectedImpact: '25% reduction in database response time',
                    estimatedEffort: '4-8 hours'
                }
            ]
        };

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify(performanceData)
        };

    } catch (error) {
        console.error('Performance monitoring error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};

/**
 * Update project status
 */
exports.updateProjectStatus = async (event) => {
    try {
        const token = event.headers.Authorization?.replace('Bearer ', '');
        if (!token) {
            return {
                statusCode: 401,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({ error: 'No token provided' })
            };
        }

        const user = verifyToken(token);
        const { projectId, status, progress, notes } = JSON.parse(event.body);

        // Update project in database
        const updateResult = await dynamodb.update({
            TableName: PROJECTS_TABLE,
            Key: { projectId },
            UpdateExpression: 'SET #status = :status, progress = :progress, notes = :notes, updatedAt = :updatedAt, updatedBy = :updatedBy',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':status': status,
                ':progress': progress,
                ':notes': notes,
                ':updatedAt': new Date().toISOString(),
                ':updatedBy': user.userId
            },
            ConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ...{
                    ':status': status,
                    ':progress': progress,
                    ':notes': notes,
                    ':updatedAt': new Date().toISOString(),
                    ':updatedBy': user.userId
                },
                ':userId': user.userId
            },
            ReturnValues: 'ALL_NEW'
        }).promise();

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                message: 'Project status updated successfully',
                project: updateResult.Attributes
            })
        };

    } catch (error) {
        console.error('Update project status error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};

// Helper functions
function calculateAverageScore(metrics) {
    const assessmentMetrics = metrics.filter(m => m.type === 'assessment' && m.score);
    if (assessmentMetrics.length === 0) return 0;
    
    const totalScore = assessmentMetrics.reduce((sum, m) => sum + m.score, 0);
    return (totalScore / assessmentMetrics.length).toFixed(1);
}

function processCostData(costData) {
    const dailyCosts = costData.map(day => ({
        date: day.TimePeriod.Start,
        cost: parseFloat(day.Total.UnblendedCost.Amount),
        services: day.Groups.map(group => ({
            service: group.Keys[0],
            cost: parseFloat(group.Metrics.UnblendedCost.Amount)
        }))
    }));

    const totalCost = dailyCosts.reduce((sum, day) => sum + day.cost, 0);
    const avgDailyCost = totalCost / dailyCosts.length;

    return {
        dailyCosts,
        totalCost: totalCost.toFixed(2),
        avgDailyCost: avgDailyCost.toFixed(2),
        trend: calculateCostTrend(dailyCosts)
    };
}

function calculateCostTrend(dailyCosts) {
    if (dailyCosts.length < 2) return 0;
    
    const recent = dailyCosts.slice(-7).reduce((sum, day) => sum + day.cost, 0) / 7;
    const previous = dailyCosts.slice(-14, -7).reduce((sum, day) => sum + day.cost, 0) / 7;
    
    return previous > 0 ? ((recent - previous) / previous * 100).toFixed(1) : 0;
}

function getRecentActivity(projects, metrics) {
    const activities = [];
    
    // Add project activities
    projects.forEach(project => {
        if (project.updatedAt) {
            activities.push({
                type: 'project',
                title: `Project "${project.name}" updated`,
                timestamp: project.updatedAt,
                details: project.status
            });
        }
    });
    
    // Add metric activities
    metrics.slice(0, 5).forEach(metric => {
        activities.push({
            type: 'assessment',
            title: `${metric.assessmentType} completed`,
            timestamp: metric.timestamp,
            details: `Score: ${metric.score || 'N/A'}`
        });
    });
    
    return activities
        .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
        .slice(0, 10);
}

function calculateProjectProgress(project) {
    if (!project.milestones) return 0;
    
    const completedMilestones = project.milestones.filter(m => m.status === 'completed').length;
    return (completedMilestones / project.milestones.length * 100).toFixed(0);
}

function calculateProjectHealth(project) {
    const now = new Date();
    const endDate = new Date(project.endDate);
    const progress = parseFloat(calculateProjectProgress(project));
    
    const timeRemaining = (endDate - now) / (1000 * 60 * 60 * 24); // days
    const totalDuration = (endDate - new Date(project.startDate)) / (1000 * 60 * 60 * 24);
    const expectedProgress = ((totalDuration - timeRemaining) / totalDuration) * 100;
    
    if (progress >= expectedProgress - 10) return 'on-track';
    if (progress >= expectedProgress - 25) return 'at-risk';
    return 'critical';
}

function getUpcomingMilestones(project) {
    if (!project.milestones) return [];
    
    const now = new Date();
    return project.milestones
        .filter(m => m.status !== 'completed' && new Date(m.dueDate) > now)
        .sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate))
        .slice(0, 3);
}

function assessProjectRisks(project) {
    const risks = [];
    const now = new Date();
    
    // Budget risk
    if (project.spentBudget / project.budget > 0.8) {
        risks.push({
            type: 'budget',
            severity: 'high',
            description: 'Budget utilization exceeds 80%'
        });
    }
    
    // Timeline risk
    const endDate = new Date(project.endDate);
    const daysRemaining = (endDate - now) / (1000 * 60 * 60 * 24);
    if (daysRemaining < 7 && project.status !== 'completed') {
        risks.push({
            type: 'timeline',
            severity: 'high',
            description: 'Project deadline approaching'
        });
    }
    
    return risks;
}

function calculateTeamUtilization(projects) {
    const teamMembers = {};
    
    projects.forEach(project => {
        if (project.teamMembers) {
            project.teamMembers.forEach(member => {
                if (!teamMembers[member.id]) {
                    teamMembers[member.id] = {
                        name: member.name,
                        role: member.role,
                        projects: 0,
                        utilization: 0
                    };
                }
                teamMembers[member.id].projects++;
                teamMembers[member.id].utilization += member.allocation || 50;
            });
        }
    });
    
    return Object.values(teamMembers);
}

function getMilestoneTimeline(projects) {
    const milestones = [];
    
    projects.forEach(project => {
        if (project.milestones) {
            project.milestones.forEach(milestone => {
                milestones.push({
                    ...milestone,
                    projectName: project.name,
                    projectId: project.projectId
                });
            });
        }
    });
    
    return milestones
        .sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate))
        .slice(0, 10);
}

function getUpcomingDeadlines(projects) {
    const now = new Date();
    const deadlines = [];
    
    projects.forEach(project => {
        const endDate = new Date(project.endDate);
        const daysRemaining = (endDate - now) / (1000 * 60 * 60 * 24);
        
        if (daysRemaining > 0 && daysRemaining <= 30) {
            deadlines.push({
                projectId: project.projectId,
                projectName: project.name,
                deadline: project.endDate,
                daysRemaining: Math.ceil(daysRemaining),
                status: project.status
            });
        }
    });
    
    return deadlines.sort((a, b) => a.daysRemaining - b.daysRemaining);
}

function getTimeRangeMs(timeRange) {
    const ranges = {
        '1h': 60 * 60 * 1000,
        '6h': 6 * 60 * 60 * 1000,
        '24h': 24 * 60 * 60 * 1000,
        '7d': 7 * 24 * 60 * 60 * 1000,
        '30d': 30 * 24 * 60 * 60 * 1000
    };
    
    return ranges[timeRange] || ranges['1h'];
}
