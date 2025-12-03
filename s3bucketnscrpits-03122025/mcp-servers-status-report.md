# MCP Servers Status Report

**Total MCP Servers Configured: 55**

Generated on: 2025-07-15

## ENABLED SERVERS (14 servers)

### AWS Labs MCP Servers (9 enabled)
1. awslabs.aws-diagram-mcp-server - Generate architecture diagrams and technical illustrations
2. awslabs.aws-documentation-mcp-server - Get latest AWS docs and APIs
3. awslabs.aws-pricing-mcp-server - Pre-deployment cost estimation and optimization
4. awslabs.cdk-mcp-server - AWS CDK development with security compliance
5. awslabs.cfn-mcp-server - Direct CloudFormation resource management via Cloud Control API
6. awslabs.core-mcp-server - Intelligent planning and AWS MCP server orchestration
7. awslabs.cost-explorer-mcp-server - Detailed cost analysis and reporting
8. awslabs.git-repo-research-mcp-server - Semantic code search and repository analysis
9. awslabs.nova-canvas-mcp-server - AI image generation with text and color guidance

### Non-AWS MCP Servers (5 enabled)
1. firecrawl-mcp - Web scraping and content extraction
2. playwright-mcp - Browser automation and testing
3. puppeteer - Browser automation and web scraping
4. sequentialthinking - Sequential thinking and problem-solving
5. time - Time zone conversion and current time utilities

## DISABLED SERVERS (41 servers)

### Data & Analytics (15 disabled)
1. awslabs.amazon-keyspaces-mcp-server - Apache Cassandra-compatible operations
2. awslabs.amazon-neptune-mcp-server - Graph database queries with openCypher and Gremlin
3. awslabs.aurora-dsql-mcp-server - Distributed SQL with PostgreSQL compatibility
4. awslabs.aws-dataprocessing-mcp-server - Comprehensive data processing tools and real-time pipeline visibility
5. awslabs.documentdb-mcp-server - MongoDB-compatible document database operations
6. awslabs.dynamodb-mcp-server - Complete DynamoDB operations and table management
7. awslabs.elasticache-mcp-server - Complete ElastiCache operations
8. awslabs.memcached-mcp-server - High-speed caching operations
9. awslabs.mysql-mcp-server - MySQL database operations via RDS Data API
10. awslabs.postgres-mcp-server - PostgreSQL database operations via RDS Data API
11. awslabs.redshift-mcp-server - Discover, explore, and query Amazon Redshift clusters
12. awslabs.s3-tables-mcp-server - Manage, query, and ingest S3-based tables with SQL support
13. awslabs.timestream-for-influxdb-mcp-server - InfluxDB-compatible operations
14. awslabs.valkey-mcp-server - Advanced data structures and caching with Valkey

### AI & Machine Learning (5 disabled)
1. awslabs.amazon-kendra-index-mcp-server - Enterprise search and RAG enhancement
2. awslabs.amazon-qbusiness-anonymous-mcp-server - AI assistant based on knowledgebase with anonymous access
3. awslabs.amazon-qindex-mcp-server - Data accessors to search through enterprise's Q index
4. awslabs.amazon-rekognition-mcp-server - Analyze images using computer vision capabilities
5. awslabs.aws-bedrock-data-automation-mcp-server - Analyze documents, images, videos, and audio files
6. awslabs.bedrock-kb-retrieval-mcp-server - Query enterprise knowledge bases with citation support

### Infrastructure & Deployment (8 disabled)
1. awslabs.aws-serverless-mcp-server - Complete serverless application lifecycle with SAM CLI
2. awslabs.aws-support-mcp-server - Create and manage AWS Support cases
3. awslabs.ecs-mcp-server - Container orchestration and ECS application deployment
4. awslabs.eks-mcp-server - Kubernetes cluster management and application deployment
5. awslabs.finch-mcp-server - Local container building with ECR integration
6. awslabs.lambda-tool-mcp-server - Execute Lambda functions as AI tools for private resource access
7. awslabs.terraform-mcp-server - Terraform workflows with integrated security scanning

### Integration & Messaging (4 disabled)
1. awslabs.amazon-mq-mcp-server - Message broker management for RabbitMQ and ActiveMQ
2. awslabs.amazon-sns-sqs-mcp-server - Event-driven messaging and queue management
3. awslabs.aws-location-mcp-server - Place search, geocoding, and route optimization
4. awslabs.stepfunctions-tool-mcp-server - Execute complex workflows and business processes

### Cost & Operations (3 disabled)
1. awslabs.cloudwatch-appsignals-mcp-server - Application monitoring and performance insights
2. awslabs.cloudwatch-mcp-server - Metrics, Alarms, and Logs analysis and operational troubleshooting
3. awslabs.prometheus-mcp-server - Prometheus-compatible operations

### Developer Tools & Support (5 disabled)
1. awslabs.aws-msk-mcp-server - Manage, monitor, and optimize Amazon MSK clusters
2. awslabs.code-doc-gen-mcp-server - Automated documentation from code analysis
3. awslabs.frontend-mcp-server - React and modern web development guidance
4. awslabs.iam-mcp-server - Comprehensive IAM user, role, group, and policy management
5. awslabs.openapi-mcp-server - Dynamic API integration through OpenAPI specifications
6. awslabs.syntheticdata-mcp-server - Generate realistic test data for development and ML

### Healthcare & Lifesciences (1 disabled)
1. awslabs.aws-healthomics-mcp-server - Generate, run, debug and optimize lifescience workflows

## Summary by Category

### Enabled Servers by Type:
- **AWS Labs Servers**: 9 enabled
- **Non-AWS Servers**: 5 enabled

### Disabled Servers by Category:
- **Data & Analytics**: 14 disabled
- **AI & Machine Learning**: 6 disabled  
- **Infrastructure & Deployment**: 7 disabled
- **Integration & Messaging**: 4 disabled
- **Cost & Operations**: 3 disabled
- **Developer Tools & Support**: 6 disabled
- **Healthcare & Lifesciences**: 1 disabled

## Notes
- All newly added servers from the AWS Labs MCP page are currently disabled as requested
- Core development and documentation servers are enabled for immediate use
- Specialized service servers are disabled to avoid resource overhead until needed
- To enable any disabled server, change `"disabled": true` to `"disabled": false` in the mcp.json configuration file
