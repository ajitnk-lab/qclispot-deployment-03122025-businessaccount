## 🚀 PROJECT PROMPT: Flask Todo WebApp with AWS CDK

### **Project Overview**
Create a serverless todo web application using Python Flask, deployed via AWS CDK
with Lambda, API Gateway, and DynamoDB. The development will be managed through 
a series of GitHub issues, each assigned to Amazon Q Developer for incremental 
implementation.
Create a new remote github repo for this project , clone ths project and work in it
Follow proper GitHub issue-based development with PRs, not direct commits to main

### **Technical Stack**
• **Backend**: Python Flask (serverless)
• **Infrastructure**: AWS CDK (Python)
• **Compute**: AWS Lambda
• **API**: Amazon API Gateway
• **Database**: Amazon DynamoDB
• **Development**: GitHub Issues + Amazon Q Developer
• **Git Operations**: GitHub MCP Server exclusively

### **Project Structure Requirements**
flask-todo-cdk/
├── app.py                 # CDK app entry point
├── requirements.txt       # CDK dependencies
├── requirements-dev.txt   # Development dependencies
├── cdk.json              # CDK configuration
├── lambda/               # Lambda function code
│   ├── todo_api/         # Flask application
│   │   ├── app.py        # Flask app
│   │   ├── models.py     # Data models
│   │   └── requirements.txt
├── infrastructure/       # CDK stacks
│   ├── __init__.py
│   ├── todo_stack.py     # Main infrastructure stack
│   └── database_stack.py # DynamoDB stack
├── tests/               # Unit tests
└── scripts/             # Deployment scripts


### **Development Workflow Instructions**

CRITICAL REQUIREMENTS:
1. Use GitHub MCP Server ONLY - No direct git commands
2. Create issues in sequence - Each building on the previous
3. Assign to Amazon Q Developer - Use "Amazon Q development agent" label
4. Incremental development - Small, focused changes per issue
5. Test each component - Validation at every step

### **Issue Series to Create**

#### **Issue #1: Project Foundation**
Title: "Setup Flask Todo CDK Project Foundation"
Labels: ["Amazon Q development agent", "setup", "foundation", "cdk"]
Priority: High

Description:
Create the basic CDK project structure for a Flask-based todo application.

Requirements:
- Initialize CDK Python project structure
- Create app.py with basic CDK app configuration
- Setup requirements.txt with CDK dependencies
- Create cdk.json with proper configuration
- Add .gitignore for Python/CDK projects
- Create basic README.md with project overview

Acceptance Criteria:
- [ ] CDK project initializes without errors
- [ ] All required directories created
- [ ] Dependencies properly defined
- [ ] Project structure follows CDK best practices


#### **Issue #2: DynamoDB Infrastructure**
Title: "Implement DynamoDB Stack for Todo Storage"
Labels: ["Amazon Q development agent", "infrastructure", "dynamodb", "cdk"]
Priority: High

Description:
Create DynamoDB table infrastructure for storing todo items.

Requirements:
- Create database_stack.py with DynamoDB table
- Configure table with appropriate partition key
- Add GSI for querying by status/date
- Implement proper IAM permissions
- Add table configuration for development/production

Table Schema:
- Partition Key: todo_id (String)
- Attributes: title, description, status, created_at, updated_at

Acceptance Criteria:
- [ ] DynamoDB table deploys successfully
- [ ] Proper indexing configured
- [ ] IAM permissions set correctly
- [ ] Table accessible from Lambda


#### **Issue #3: Flask Application Core**
Title: "Create Flask Todo API Application"
Labels: ["Amazon Q development agent", "flask", "api", "lambda"]
Priority: High

Description:
Develop the core Flask application for todo management.

Requirements:
- Create lambda/todo_api/app.py with Flask app
- Implement models.py for todo data structure
- Create API endpoints: GET, POST, PUT, DELETE /todos
- Add proper error handling and validation
- Configure Flask for Lambda deployment
- Add logging and monitoring

API Endpoints:
- GET /todos - List all todos
- POST /todos - Create new todo
- GET /todos/{id} - Get specific todo
- PUT /todos/{id} - Update todo
- DELETE /todos/{id} - Delete todo

Acceptance Criteria:
- [ ] Flask app runs locally
- [ ] All CRUD operations implemented
- [ ] Proper error handling
- [ ] Input validation working
- [ ] Logging configured


#### **Issue #4: Lambda Infrastructure**
Title: "Implement Lambda Function Infrastructure"
Labels: ["Amazon Q development agent", "lambda", "infrastructure", "cdk"]
Priority: High

Description:
Create Lambda function infrastructure to host the Flask application.

Requirements:
- Create Lambda function in todo_stack.py
- Configure Python runtime and dependencies
- Set up environment variables for DynamoDB
- Configure proper IAM roles and policies
- Add Lambda layers if needed
- Set appropriate timeout and memory settings

Configuration:
- Runtime: Python 3.11
- Memory: 512MB
- Timeout: 30 seconds
- Environment: DynamoDB table name

Acceptance Criteria:
- [ ] Lambda function deploys successfully
- [ ] Flask app accessible via Lambda
- [ ] DynamoDB connection working
- [ ] Proper error handling
- [ ] Performance optimized


#### **Issue #5: API Gateway Integration**
Title: "Setup API Gateway for Flask Todo API"
Labels: ["Amazon Q development agent", "api-gateway", "infrastructure", "cdk"]
Priority: High

Description:
Configure API Gateway to expose the Flask Lambda function.

Requirements:
- Create API Gateway REST API
- Configure Lambda proxy integration
- Set up proper CORS headers
- Add request/response validation
- Configure API Gateway stages (dev/prod)
- Add throttling and rate limiting

API Configuration:
- Base path: /api/v1
- CORS: Allow all origins for development
- Authentication: None (for now)
- Throttling: 1000 requests/minute

Acceptance Criteria:
- [ ] API Gateway deploys successfully
- [ ] All Flask routes accessible via API
- [ ] CORS configured properly
- [ ] Request validation working
- [ ] API documentation generated


#### **Issue #6: Testing and Validation**
Title: "Implement Comprehensive Testing Suite"
Labels: ["Amazon Q development agent", "testing", "validation", "quality"]
Priority: Medium

Description:
Create comprehensive tests for the todo application.

Requirements:
- Unit tests for Flask application
- Integration tests for DynamoDB operations
- CDK infrastructure tests
- API endpoint testing
- Performance and load testing setup
- Test data fixtures and mocking

Test Coverage:
- Flask route handlers
- DynamoDB CRUD operations
- CDK stack synthesis
- API Gateway integration
- Error handling scenarios

Acceptance Criteria:
- [ ] All tests pass successfully
- [ ] Code coverage > 80%
- [ ] Integration tests working
- [ ] Performance benchmarks established
- [ ] CI/CD pipeline ready


#### **Issue #7: Deployment and Documentation**
Title: "Finalize Deployment and Documentation"
Labels: ["Amazon Q development agent", "deployment", "documentation", "production"]
Priority: Medium

Description:
Complete deployment automation and comprehensive documentation.

Requirements:
- Create deployment scripts
- Add environment-specific configurations
- Complete API documentation
- Add troubleshooting guide
- Create user manual
- Setup monitoring and logging

Documentation:
- README with setup instructions
- API documentation with examples
- Deployment guide
- Architecture diagrams
- Troubleshooting guide

Acceptance Criteria:
- [ ] One-command deployment working
- [ ] Documentation complete and accurate
- [ ] Monitoring configured
- [ ] Production-ready configuration
- [ ] User guide available


### **GitHub MCP Server Operations Required**

For each issue, use these MCP server operations:
1. Create Issue: github_mcp_server___create_issue
2. Add Labels: Include "Amazon Q development agent" label
3. Add Comments: Progress updates and testing results
4. File Operations: github_mcp_server___create_or_update_file
5. Branch Management: github_mcp_server___create_branch
6. Pull Requests: github_mcp_server___create_pull_request

### **Implementation Command**

Execute this prompt by:
1. Creating a new repository for the project
2. Creating each issue in sequence using GitHub MCP server
3. Assigning each issue the "Amazon Q development agent" label
4. Monitoring progress and adding comments as needed
5. Validating each component before proceeding to the next issue

Start with Issue #1 and proceed sequentially through all 7 issues.
