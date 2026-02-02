# Create Data Engineer Agent App - SPCS App

An intelligent Snowflake agent that automatically generates DDL and sets up data pipelines for external data sources.

> **✨ Updated February 2026**: Now includes production-tested patterns, comprehensive troubleshooting guides, and real-world debugging solutions. See [SKILL_UPDATE_SUMMARY.md](SKILL_UPDATE_SUMMARY.md) for latest improvements.

> **📝 Note on Placeholders**: This documentation uses placeholders like `<DATABASE>`, `<WAREHOUSE>`, `<AGENT_NAME>`, and `<connection>` throughout. Replace these with your actual Snowflake object names and connection details when deploying.

## 🎯 Features

- **Storage Integration Generation**: Automatically creates storage integrations for AWS S3, Azure Blob Storage, and Google Cloud Storage
- **File Format Creation**: Generates file formats for CSV, JSON, Parquet, Avro, and ORC files
- **External Stage Setup**: Creates external stages pointing to your cloud storage
- **External Table Building**: Generates and deploys external table DDL
- **Pipeline Tracking**: Tracks all pipeline creations in a centralized table
- **Interactive Dashboard**: Streamlit UI for easy interaction with the agent

## 📋 Architecture

### Components

1. **Cortex Agent** (`<AGENT_NAME>`)
   - Orchestrates the pipeline creation workflow
   - Uses 5 custom stored procedures as tools
   - Deployed in: `<DATABASE>.PUBLIC.<AGENT_NAME>`

2. **Custom Tools (Stored Procedures)**
   - `GENERATE_STORAGE_INTEGRATION_DDL`: Creates storage integration DDL
   - `GENERATE_FILE_FORMAT_DDL`: Creates file format DDL
   - `GENERATE_EXTERNAL_STAGE_DDL`: Creates external stage DDL
   - `GENERATE_EXTERNAL_TABLE_DDL`: Creates external table DDL
   - `EXECUTE_DDL_AND_TRACK`: Executes DDL and tracks in pipeline tracker table

3. **Pipeline Tracker Table** (`DATA_PIPELINE_TRACKER`)
   - Stores all pipeline creation history
   - Tracks success/failure status
   - Stores execution logs

4. **Streamlit Dashboard**
   - User-friendly interface for describing data sources
   - Real-time pipeline tracking
   - Quick setup form for common scenarios

5. **SPCS Deployment**
   - Containerized Streamlit app
   - Runs in Snowpark Container Services
   - Public endpoint for easy access

## 🚀 Deployment Guide

### Prerequisites

- Snowflake account with SPCS enabled
- Docker installed locally
- Snow CLI configured with connection named '<connection>'
- ACCOUNTADMIN role access
- Warehouse: <WAREHOUSE>

### Step 1: Review the Agent (Already Created)

The agent has been created in Snowflake:

```sql
USE ROLE ACCOUNTADMIN;
DESCRIBE AGENT <DATABASE>.PUBLIC.<AGENT_NAME>;
```

### Step 2: Deploy to SPCS

Run the deployment script:

```bash
cd /Users/leyu/<AGENT_NAME>
./deploy.sh
```

This script will:
1. Create image repository
2. Build Docker image
3. Push to Snowflake registry
4. Create compute pool
5. Deploy service

### Step 3: Access the Dashboard

After deployment, get the endpoint URL:

```bash
snow sql -q "SHOW ENDPOINTS IN SERVICE DATA_ENGINEER_SERVICE;" -c <connection>
```

## 📖 Usage Examples

### Example 1: AWS S3 CSV Files

User message:
```
I have CSV files in s3://my-sales-bucket/data/ with columns: 
order_id, customer_name, amount, order_date
```

The agent will:
1. Ask for AWS role ARN and credentials info
2. Generate storage integration DDL
3. Generate CSV file format DDL
4. Generate external stage DDL
5. Generate external table DDL with the specified columns
6. Execute all DDL upon approval
7. Track the pipeline in DATA_PIPELINE_TRACKER

### Example 2: Azure Parquet Files

User message:
```
Set up a pipeline for Azure Blob Storage at 
azure://mystorageaccount.blob.core.windows.net/container/logs/
with Parquet files
```

The agent will handle the Azure-specific requirements automatically.

### Example 3: GCS JSON Files

User message:
```
I need to query JSON files from gs://my-gcs-bucket/events/
```

The agent will create the necessary GCS integration and setup.

## 🔧 Agent Configuration

### Models
- **Orchestration**: auto (automatically selects best model)

### Budget
- **Seconds**: 900 (15 minutes)
- **Tokens**: 400,000

### Tools
1. **generate_storage_integration**
   - Input: integration_name, cloud_provider, storage_aws_role_arn, storage_allowed_locations, azure_tenant_id, gcs_service_account
   - Output: DDL string

2. **generate_file_format**
   - Input: format_name, format_type, compression, field_delimiter, skip_header, trim_space, error_on_column_count_mismatch
   - Output: DDL string

3. **generate_external_stage**
   - Input: stage_name, url, storage_integration, file_format, credentials
   - Output: DDL string

4. **generate_external_table**
   - Input: table_name, stage_name, file_format, columns, partition_by, auto_refresh
   - Output: DDL string

5. **execute_pipeline_ddl**
   - Input: pipeline_id, data_source_type, ddl_statements[]
   - Output: Execution status and log

## 📊 Pipeline Tracking

View all created pipelines:

```sql
SELECT * 
FROM <DATABASE>.PUBLIC.DATA_PIPELINE_TRACKER
ORDER BY CREATED_AT DESC;
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### Issue: Stage query fails with "SELECT with no columns"
**Cause**: Using `SELECT *` on Snowflake stages  
**Solution**: Use positional notation ($1, $2, $3...) - see [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

#### Issue: External table returns no data
**Cause**: File paths with spaces or LOCATION mismatch  
**Solution**: Create staging table instead - see [SKILL.md](SKILL.md#issue-external-table-queries-return-no-data)

#### Issue: CSV data misaligned
**Cause**: Missing SKIP_HEADER parameter  
**Solution**: Set `SKIP_HEADER = 1` in file format

For complete troubleshooting guide, see [SKILL.md - Troubleshooting Workflow](SKILL.md#troubleshooting-workflow)

### Check Service Status

```sql
CALL SYSTEM$GET_SERVICE_STATUS('DATA_ENGINEER_SERVICE');
```

### View Service Logs

```sql
CALL SYSTEM$GET_SERVICE_LOGS('DATA_ENGINEER_SERVICE', '0', 'data-engineer-agent');
```

### Test Agent Directly

```sql
-- Create a thread
SELECT SYSTEM$CREATE_CORTEX_THREAD('test_session');

-- Send a message (replace <thread_id> with actual thread ID from above)
SELECT SYSTEM$RUN_CORTEX_AGENT(
    '<DATABASE>.PUBLIC.<AGENT_NAME>',
    '<thread_id>',
    PARSE_JSON('{"messages": [{"role": "user", "content": "Help me set up an S3 pipeline"}]}')
);
```

### Redeploy Service

```sql
ALTER SERVICE DATA_ENGINEER_SERVICE SUSPEND;
ALTER SERVICE DATA_ENGINEER_SERVICE RESUME;
```

## 🔒 Security Considerations

1. **IAM Roles**: External storage integrations require proper IAM role setup in your cloud provider
2. **Access Control**: Grant appropriate Snowflake roles access to the agent and pipelines
3. **Credentials**: Never hardcode credentials - always use storage integrations
4. **Permissions**: The agent runs with the user's permissions (RBAC applies automatically)

## 📝 Grant Access Example

To grant other roles access to the agent:

```sql
GRANT USAGE ON AGENT <DATABASE>.PUBLIC.<AGENT_NAME> TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE <DATABASE> TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA <DATABASE>.PUBLIC TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE <WAREHOUSE> TO ROLE DATA_ENGINEER;
```

## 📚 Documentation

### Quick Start
- **[START_HERE.md](START_HERE.md)** - Getting started guide
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - One-page cheat sheet for common patterns

### Detailed Guides
- **[SKILL.md](SKILL.md)** - Complete skill documentation with step-by-step instructions
- **[SKILL_UPDATE_SUMMARY.md](SKILL_UPDATE_SUMMARY.md)** - Recent improvements and lessons learned
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
- **[DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)** - Deployment options and instructions

### Examples
- **[examples/pages/Data_Preview.py](examples/pages/Data_Preview.py)** - Production-ready data preview page with multiple query methods

### Snowflake Documentation
- [Snowflake Cortex Agents Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Snowpark Container Services Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
- [External Tables Documentation](https://docs.snowflake.com/en/user-guide/tables-external-intro)

## 🎉 Next Steps

After deployment, you can:

1. Access the Streamlit dashboard via the SPCS endpoint
2. Describe your data sources in natural language
3. Review and approve generated DDL
4. Monitor pipeline creation in the tracker
5. Query your external data directly in Snowflake

## 📦 Project Structure

```
<AGENT_NAME>/
├── agent_spec.json              # Agent configuration
├── streamlit_app.py             # Streamlit dashboard
├── Dockerfile                   # Container image definition
├── requirements.txt             # Python dependencies
├── spec.yaml                    # SPCS service specification
├── deploy.sh                    # Deployment script
├── create_agent.sql             # SQL script that created the agent
├── metadata.yaml                # Project metadata
└── README.md                    # This file
```

## 🏗️ Built With

- **Snowflake Cortex Agents**: AI orchestration
- **Python 3.11**: Stored procedures and Streamlit app
- **Streamlit**: Interactive dashboard
- **Docker**: Containerization
- **Snowpark Container Services**: Cloud-native deployment
- **Snowflake REST API**: Agent interaction

---

**Agent**: `<DATABASE>.PUBLIC.<AGENT_NAME>`  
**Service**: `DATA_ENGINEER_SERVICE`  
**Pool**: `DATA_ENGINEER_POOL`  
**Status**: ✅ Ready to deploy
