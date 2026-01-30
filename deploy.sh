#!/bin/bash

set -e

echo "🔧 Building and Deploying Data Engineer Agent to SPCS..."

echo "Step 1: Create image repository"
snow sql -q "
USE ROLE ACCOUNTADMIN;
USE DATABASE LEILA_APP;
USE SCHEMA PUBLIC;

CREATE IMAGE REPOSITORY IF NOT EXISTS DATA_ENGINEER_REPO;
SHOW IMAGE REPOSITORIES;
" -c pm

echo "Step 2: Get repository URL"
REPO_URL=$(snow sql -q "SHOW IMAGE REPOSITORIES IN SCHEMA LEILA_APP.PUBLIC;" -c pm --format json | python3 -c "
import sys, json
repos = json.load(sys.stdin)
for repo in repos:
    if repo['name'] == 'DATA_ENGINEER_REPO':
        print(repo['repository_url'])
        break
")

echo "Repository URL: $REPO_URL"

echo "Step 3: Build Docker image"
docker build --platform linux/amd64 -t data_engineer_agent:latest .

echo "Step 4: Tag image"
docker tag data_engineer_agent:latest $REPO_URL/data_engineer_agent:latest

echo "Step 5: Login to Snowflake registry"
snow spcs image-registry login -c pm

echo "Step 6: Push image"
docker push $REPO_URL/data_engineer_agent:latest

echo "Step 7: Create compute pool (if not exists)"
snow sql -q "
CREATE COMPUTE POOL IF NOT EXISTS DATA_ENGINEER_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;
" -c pm

echo "Step 8: Wait for compute pool to be ready"
echo "Checking compute pool status..."
sleep 10

echo "Step 9: Create service"
snow sql -q "
CREATE SERVICE IF NOT EXISTS DATA_ENGINEER_SERVICE
  IN COMPUTE POOL DATA_ENGINEER_POOL
  FROM SPECIFICATION \$\$
spec:
  containers:
  - name: data-engineer-agent
    image: $REPO_URL/data_engineer_agent:latest
    env:
      SNOWFLAKE_ACCOUNT: pm-pm_aws_us_west_2
  endpoints:
  - name: streamlit
    port: 8501
    public: true
\$\$;
" -c pm

echo "Step 10: Check service status"
snow sql -q "
SHOW SERVICES LIKE 'DATA_ENGINEER_SERVICE';
DESCRIBE SERVICE DATA_ENGINEER_SERVICE;
" -c pm

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To get the service endpoint URL, run:"
echo "  snow sql -q \"SHOW ENDPOINTS IN SERVICE DATA_ENGINEER_SERVICE;\" -c pm"
echo ""
echo "To check service status:"
echo "  snow sql -q \"CALL SYSTEM\$GET_SERVICE_STATUS('DATA_ENGINEER_SERVICE');\" -c pm"
echo ""
echo "To check logs:"
echo "  snow sql -q \"CALL SYSTEM\$GET_SERVICE_LOGS('DATA_ENGINEER_SERVICE', '0', 'data-engineer-agent');\" -c pm"
