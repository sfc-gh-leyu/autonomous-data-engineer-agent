---
name: autonomous-data-engineer-agent
description: "Create an autonomous data engineer agent that generates DDL and sets up data pipelines. The agent uses custom stored procedures as tools to handle storage integrations, file formats, external stages, and external tables for AWS S3, Azure, and GCS. Includes Streamlit dashboard and SPCS deployment."
triggers:
  - "create autonomous data engineer agent"
  - "build data pipeline agent"
  - "agent that creates external tables"
  - "automate data pipeline setup"
  - "agent for DDL generation"
  - "data engineer automation agent"
---

# Autonomous Data Engineer Agent

## Overview

This skill creates a Cortex Agent that autonomously generates and executes DDL for data pipeline setup. Users describe their data sources in natural language, and the agent:
- Creates storage integrations (AWS S3, Azure, GCS)
- Generates file formats (CSV, JSON, Parquet, Avro, ORC)
- Sets up external stages
- Creates external tables
- Executes and tracks all pipeline creations

The deliverable includes:
1. Cortex Agent with 5 custom tool stored procedures
2. Pipeline tracking table
3. Streamlit dashboard for user interaction
4. SPCS deployment configuration

## When to Use

- User wants to automate data pipeline creation
- User needs an agent that generates DDL
- User wants to set up external tables via natural language
- User needs multi-cloud storage integration (AWS/Azure/GCS)
- User wants a self-service data engineering tool

## Prerequisites Check

Before starting, verify:
```sql
-- Check user has appropriate role
SELECT CURRENT_ROLE();

-- Check warehouse exists
SHOW WAREHOUSES;

-- Verify agent creation privileges
SHOW GRANTS TO ROLE <role_name>;
```

Required:
- CREATE AGENT privilege on target schema
- CREATE PROCEDURE privilege
- CREATE TABLE privilege
- Appropriate warehouse access

## Workflow

### Step 1: Gather Requirements

Use `ask_user_question` tool to collect:

```json
{
  "questions": [
    {
      "header": "Database",
      "question": "Which database should I create the agent in?",
      "type": "text",
      "defaultValue": "MY_DATABASE",
      "multiSelect": false
    },
    {
      "header": "Schema",
      "question": "Which schema should I create the agent in?",
      "type": "text",
      "defaultValue": "PUBLIC",
      "multiSelect": false
    },
    {
      "header": "Agent Name",
      "question": "What should the agent be called?",
      "type": "text",
      "defaultValue": "DATA_ENGINEER_AGENT",
      "multiSelect": false
    },
    {
      "header": "Role",
      "question": "Which role should be used for agent creation?",
      "type": "text",
      "defaultValue": "ACCOUNTADMIN",
      "multiSelect": false
    },
    {
      "header": "Warehouse",
      "question": "Which warehouse should the agent use for tool execution?",
      "type": "text",
      "defaultValue": "COMPUTE_WH",
      "multiSelect": false
    },
    {
      "header": "Data Sources",
      "question": "Which data source types should the agent support?",
      "type": "options",
      "multiSelect": true,
      "options": [
        {
          "label": "AWS S3",
          "description": "AWS S3 buckets with external stages and integrations"
        },
        {
          "label": "Azure",
          "description": "Azure Blob Storage with external stages"
        },
        {
          "label": "GCS",
          "description": "Google Cloud Storage"
        },
        {
          "label": "All providers",
          "description": "All cloud providers"
        }
      ]
    }
  ]
}
```

### Step 2: Create Workspace

Create a project directory:

```bash
mkdir -p <AGENT_NAME>
cd <AGENT_NAME>

# Create metadata file
cat > metadata.yaml << EOF
database: <DATABASE>
schema: <SCHEMA>
role: <ROLE>
agent_name: <AGENT_NAME>
warehouse: <WAREHOUSE>
EOF
```

### Step 3: Create Stored Procedure Tools

**CRITICAL**: Create stored procedures in this exact order before creating the agent.

#### 3.1 Storage Integration Generator

```sql
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.GENERATE_STORAGE_INTEGRATION_DDL(
    INTEGRATION_NAME STRING,
    CLOUD_PROVIDER STRING,
    STORAGE_AWS_ROLE_ARN STRING DEFAULT NULL,
    STORAGE_ALLOWED_LOCATIONS ARRAY DEFAULT NULL,
    AZURE_TENANT_ID STRING DEFAULT NULL,
    AZURE_CONSENT_URL STRING DEFAULT NULL,
    GCS_SERVICE_ACCOUNT STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_ddl'
AS $$
def generate_ddl(session, integration_name, cloud_provider, storage_aws_role_arn, 
                 storage_allowed_locations, azure_tenant_id, azure_consent_url, gcs_service_account):
    
    cloud_provider = cloud_provider.upper()
    
    if not storage_allowed_locations or len(storage_allowed_locations) == 0:
        return "Error: STORAGE_ALLOWED_LOCATIONS must be provided"
    
    locations_str = ", ".join([f"'{loc}'" for loc in storage_allowed_locations])
    
    if cloud_provider == 'AWS' or cloud_provider == 'S3':
        if not storage_aws_role_arn:
            return "Error: STORAGE_AWS_ROLE_ARN required for AWS"
        
        ddl = f"""CREATE OR REPLACE STORAGE INTEGRATION {integration_name}
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '{storage_aws_role_arn}'
  STORAGE_ALLOWED_LOCATIONS = ({locations_str});"""
    
    elif cloud_provider == 'AZURE':
        if not azure_tenant_id:
            return "Error: AZURE_TENANT_ID required for Azure"
        
        ddl = f"""CREATE OR REPLACE STORAGE INTEGRATION {integration_name}
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '{azure_tenant_id}'
  STORAGE_ALLOWED_LOCATIONS = ({locations_str});"""
    
    elif cloud_provider == 'GCS':
        ddl = f"""CREATE OR REPLACE STORAGE INTEGRATION {integration_name}
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'GCS'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ({locations_str});"""
    
    else:
        return f"Error: Unsupported cloud provider '{cloud_provider}'. Use AWS, AZURE, or GCS"
    
    return ddl
$$;
```

#### 3.2 File Format Generator

```sql
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.GENERATE_FILE_FORMAT_DDL(
    FORMAT_NAME STRING,
    FORMAT_TYPE STRING,
    COMPRESSION STRING DEFAULT 'AUTO',
    FIELD_DELIMITER STRING DEFAULT ',',
    SKIP_HEADER INT DEFAULT 0,
    TRIM_SPACE BOOLEAN DEFAULT FALSE,
    ERROR_ON_COLUMN_COUNT_MISMATCH BOOLEAN DEFAULT TRUE
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_ddl'
AS $$
def generate_ddl(session, format_name, format_type, compression, field_delimiter, 
                 skip_header, trim_space, error_on_column_count_mismatch):
    
    format_type = format_type.upper()
    
    if format_type == 'CSV':
        ddl = f"""CREATE OR REPLACE FILE FORMAT {format_name}
  TYPE = CSV
  COMPRESSION = '{compression}'
  FIELD_DELIMITER = '{field_delimiter}'
  SKIP_HEADER = {skip_header}
  TRIM_SPACE = {str(trim_space).upper()}
  ERROR_ON_COLUMN_COUNT_MISMATCH = {str(error_on_column_count_mismatch).upper()};"""
    
    elif format_type == 'JSON':
        ddl = f"""CREATE OR REPLACE FILE FORMAT {format_name}
  TYPE = JSON
  COMPRESSION = '{compression}'
  TRIM_SPACE = {str(trim_space).upper()};"""
    
    elif format_type == 'PARQUET':
        ddl = f"""CREATE OR REPLACE FILE FORMAT {format_name}
  TYPE = PARQUET
  COMPRESSION = '{compression}';"""
    
    elif format_type == 'AVRO':
        ddl = f"""CREATE OR REPLACE FILE FORMAT {format_name}
  TYPE = AVRO
  COMPRESSION = '{compression}';"""
    
    elif format_type == 'ORC':
        ddl = f"""CREATE OR REPLACE FILE FORMAT {format_name}
  TYPE = ORC
  TRIM_SPACE = {str(trim_space).upper()};"""
    
    else:
        return f"Error: Unsupported format type '{format_type}'. Use CSV, JSON, PARQUET, AVRO, or ORC"
    
    return ddl
$$;
```

#### 3.3 External Stage Generator

```sql
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.GENERATE_EXTERNAL_STAGE_DDL(
    STAGE_NAME STRING,
    URL STRING,
    STORAGE_INTEGRATION STRING DEFAULT NULL,
    FILE_FORMAT STRING DEFAULT NULL,
    CREDENTIALS STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_ddl'
AS $$
def generate_ddl(session, stage_name, url, storage_integration, file_format, credentials):
    
    if not url:
        return "Error: URL is required for external stage"
    
    ddl = f"CREATE OR REPLACE STAGE {stage_name}\n  URL = '{url}'"
    
    if storage_integration:
        ddl += f"\n  STORAGE_INTEGRATION = {storage_integration}"
    elif credentials:
        ddl += f"\n  CREDENTIALS = ({credentials})"
    
    if file_format:
        ddl += f"\n  FILE_FORMAT = {file_format}"
    
    ddl += ";"
    
    return ddl
$$;
```

#### 3.4 External Table Generator

```sql
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.GENERATE_EXTERNAL_TABLE_DDL(
    TABLE_NAME STRING,
    STAGE_NAME STRING,
    FILE_FORMAT STRING,
    COLUMNS ARRAY,
    PARTITION_BY STRING DEFAULT NULL,
    AUTO_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'generate_ddl'
AS $$
def generate_ddl(session, table_name, stage_name, file_format, columns, partition_by, auto_refresh):
    
    if not columns or len(columns) == 0:
        return "Error: COLUMNS array must contain at least one column definition (format: 'column_name TYPE')"
    
    columns_str = ",\n  ".join(columns)
    
    ddl = f"""CREATE OR REPLACE EXTERNAL TABLE {table_name} (
  {columns_str}
)"""
    
    if partition_by:
        ddl += f"\nPARTITION BY ({partition_by})"
    
    ddl += f"\nLOCATION = @{stage_name}"
    ddl += f"\nFILE_FORMAT = {file_format}"
    
    if auto_refresh:
        ddl += "\nAUTO_REFRESH = TRUE"
    
    ddl += ";"
    
    return ddl
$$;
```

#### 3.5 Pipeline Tracker Table and Executor

```sql
-- Create tracker table
CREATE TABLE IF NOT EXISTS <DATABASE>.<SCHEMA>.DATA_PIPELINE_TRACKER (
    PIPELINE_ID STRING,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    DATA_SOURCE_TYPE STRING,
    INTEGRATION_NAME STRING,
    STAGE_NAME STRING,
    FILE_FORMAT_NAME STRING,
    TABLE_NAME STRING,
    STATUS STRING,
    DDL_STATEMENTS VARIANT,
    EXECUTION_LOG VARIANT
);

-- Create executor procedure
CREATE OR REPLACE PROCEDURE <DATABASE>.<SCHEMA>.EXECUTE_DDL_AND_TRACK(
    PIPELINE_ID STRING,
    DATA_SOURCE_TYPE STRING,
    DDL_STATEMENTS ARRAY
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'execute_and_track'
AS $$
import json
from datetime import datetime

def execute_and_track(session, pipeline_id, data_source_type, ddl_statements):
    
    execution_log = []
    status = 'SUCCESS'
    
    try:
        for i, ddl in enumerate(ddl_statements):
            try:
                session.sql(ddl).collect()
                execution_log.append({
                    'step': i + 1,
                    'ddl': ddl,
                    'status': 'SUCCESS',
                    'timestamp': datetime.now().isoformat()
                })
            except Exception as e:
                execution_log.append({
                    'step': i + 1,
                    'ddl': ddl,
                    'status': 'FAILED',
                    'error': str(e),
                    'timestamp': datetime.now().isoformat()
                })
                status = 'FAILED'
                break
        
        # Escape single quotes in JSON for SQL
        ddl_json = json.dumps(ddl_statements).replace("'", "''")
        log_json = json.dumps(execution_log).replace("'", "''")
        
        session.sql(f"""
            INSERT INTO <DATABASE>.<SCHEMA>.DATA_PIPELINE_TRACKER 
            (PIPELINE_ID, DATA_SOURCE_TYPE, STATUS, DDL_STATEMENTS, EXECUTION_LOG)
            VALUES ('{pipeline_id}', '{data_source_type}', '{status}', 
                    PARSE_JSON('{ddl_json}'), 
                    PARSE_JSON('{log_json}'))
        """).collect()
        
        return json.dumps({
            'pipeline_id': pipeline_id,
            'status': status,
            'executed_steps': len(execution_log),
            'execution_log': execution_log
        })
    
    except Exception as e:
        return json.dumps({
            'pipeline_id': pipeline_id,
            'status': 'ERROR',
            'error': str(e)
        })
$$;
```

### Step 4: Create Agent Specification

Create `agent_spec.json`:

```json
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You are an autonomous data engineer agent. Your role is to help users set up data pipelines by generating and executing DDL for storage integrations, file formats, external stages, and external tables. When a user describes a new data source:\n\n1. Ask clarifying questions to gather all required information (cloud provider, bucket/container URL, credentials, file format, table schema)\n2. Generate the appropriate DDL statements using your tools in this order:\n   - Storage integration (if needed)\n   - File format\n   - External stage\n   - External table\n3. Show the generated DDL to the user for review\n4. Execute the DDL when the user approves\n5. Track the pipeline creation in the DATA_PIPELINE_TRACKER table\n\nSupported cloud providers: AWS S3, Azure Blob Storage, Google Cloud Storage\nSupported file formats: CSV, JSON, Parquet, Avro, ORC\n\nAlways provide clear explanations of what each DDL statement does and why it's needed.",
    "response": "Format your responses clearly with:\n- Section headers for each step\n- Code blocks for DDL statements\n- Bullet points for requirements and instructions\n- Clear next steps for the user\n\nWhen showing DDL, always explain what it creates and what permissions/setup might be needed externally (like IAM roles for AWS)."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "generic",
        "name": "generate_storage_integration",
        "description": "Generate DDL for creating a storage integration to connect Snowflake to cloud storage (AWS S3, Azure Blob Storage, or GCS). This must be created first before external stages.",
        "input_schema": {
          "type": "object",
          "properties": {
            "integration_name": {
              "type": "string",
              "description": "Name for the storage integration (e.g., MY_S3_INTEGRATION)"
            },
            "cloud_provider": {
              "type": "string",
              "enum": ["AWS", "S3", "AZURE", "GCS"],
              "description": "Cloud provider: AWS/S3, AZURE, or GCS"
            },
            "storage_aws_role_arn": {
              "type": "string",
              "description": "AWS IAM role ARN (required for AWS). Example: arn:aws:iam::123456789012:role/SnowflakeRole"
            },
            "storage_allowed_locations": {
              "type": "array",
              "items": {"type": "string"},
              "description": "Array of allowed storage locations (bucket URLs). Example: ['s3://my-bucket/path/', 's3://another-bucket/']"
            },
            "azure_tenant_id": {
              "type": "string",
              "description": "Azure tenant ID (required for Azure)"
            },
            "gcs_service_account": {
              "type": "string",
              "description": "GCS service account (optional for GCS)"
            }
          },
          "required": ["integration_name", "cloud_provider", "storage_allowed_locations"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "generate_file_format",
        "description": "Generate DDL for creating a file format that defines how data files should be parsed (CSV, JSON, Parquet, Avro, ORC).",
        "input_schema": {
          "type": "object",
          "properties": {
            "format_name": {"type": "string", "description": "Name for the file format (e.g., MY_CSV_FORMAT)"},
            "format_type": {"type": "string", "enum": ["CSV", "JSON", "PARQUET", "AVRO", "ORC"], "description": "Type of file format"},
            "compression": {"type": "string", "enum": ["AUTO", "GZIP", "BZ2", "BROTLI", "ZSTD", "DEFLATE", "RAW_DEFLATE", "NONE"], "description": "Compression type (default: AUTO)"},
            "field_delimiter": {"type": "string", "description": "Field delimiter for CSV files (default: ',')"},
            "skip_header": {"type": "integer", "description": "Number of header lines to skip (default: 0)"},
            "trim_space": {"type": "boolean", "description": "Whether to trim whitespace from fields (default: false)"},
            "error_on_column_count_mismatch": {"type": "boolean", "description": "Whether to error if column count doesn't match (default: true)"}
          },
          "required": ["format_name", "format_type"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "generate_external_stage",
        "description": "Generate DDL for creating an external stage that points to cloud storage. Requires a storage integration or credentials.",
        "input_schema": {
          "type": "object",
          "properties": {
            "stage_name": {"type": "string", "description": "Name for the external stage (e.g., MY_S3_STAGE)"},
            "url": {"type": "string", "description": "URL to cloud storage location. Examples: s3://bucket/path/, azure://account.blob.core.windows.net/container/, gcs://bucket/path/"},
            "storage_integration": {"type": "string", "description": "Name of the storage integration to use (recommended)"},
            "file_format": {"type": "string", "description": "Name of the file format to use (optional, can be specified later)"},
            "credentials": {"type": "string", "description": "Inline credentials string (alternative to storage integration, not recommended for production)"}
          },
          "required": ["stage_name", "url"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "generate_external_table",
        "description": "Generate DDL for creating an external table that queries data directly from cloud storage through an external stage.",
        "input_schema": {
          "type": "object",
          "properties": {
            "table_name": {"type": "string", "description": "Name for the external table (e.g., MY_EXTERNAL_TABLE)"},
            "stage_name": {"type": "string", "description": "Name of the external stage to use"},
            "file_format": {"type": "string", "description": "Name of the file format to use"},
            "columns": {"type": "array", "items": {"type": "string"}, "description": "Array of column definitions. Format: 'COLUMN_NAME TYPE'. Example: ['ID NUMBER', 'NAME VARCHAR', 'CREATED_DATE TIMESTAMP']"},
            "partition_by": {"type": "string", "description": "Partition expression (optional). Example: 'TO_DATE(CREATED_DATE)'"},
            "auto_refresh": {"type": "boolean", "description": "Whether to enable automatic metadata refresh (default: false)"}
          },
          "required": ["table_name", "stage_name", "file_format", "columns"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "execute_pipeline_ddl",
        "description": "Execute the generated DDL statements and track the pipeline creation. Use this after the user approves the generated DDL.",
        "input_schema": {
          "type": "object",
          "properties": {
            "pipeline_id": {"type": "string", "description": "Unique identifier for this pipeline (use UUID or descriptive name)"},
            "data_source_type": {"type": "string", "description": "Type/description of the data source (e.g., 'AWS_S3_SALES_DATA', 'AZURE_LOGS')"},
            "ddl_statements": {"type": "array", "items": {"type": "string"}, "description": "Array of DDL statements to execute in order"}
          },
          "required": ["pipeline_id", "data_source_type", "ddl_statements"]
        }
      }
    }
  ],
  "tool_resources": {
    "generate_storage_integration": {
      "type": "procedure",
      "identifier": "<DATABASE>.<SCHEMA>.GENERATE_STORAGE_INTEGRATION_DDL",
      "execution_environment": {"type": "warehouse", "warehouse": "<WAREHOUSE>", "query_timeout": 300}
    },
    "generate_file_format": {
      "type": "procedure",
      "identifier": "<DATABASE>.<SCHEMA>.GENERATE_FILE_FORMAT_DDL",
      "execution_environment": {"type": "warehouse", "warehouse": "<WAREHOUSE>", "query_timeout": 300}
    },
    "generate_external_stage": {
      "type": "procedure",
      "identifier": "<DATABASE>.<SCHEMA>.GENERATE_EXTERNAL_STAGE_DDL",
      "execution_environment": {"type": "warehouse", "warehouse": "<WAREHOUSE>", "query_timeout": 300}
    },
    "generate_external_table": {
      "type": "procedure",
      "identifier": "<DATABASE>.<SCHEMA>.GENERATE_EXTERNAL_TABLE_DDL",
      "execution_environment": {"type": "warehouse", "warehouse": "<WAREHOUSE>", "query_timeout": 300}
    },
    "execute_pipeline_ddl": {
      "type": "procedure",
      "identifier": "<DATABASE>.<SCHEMA>.EXECUTE_DDL_AND_TRACK",
      "execution_environment": {"type": "warehouse", "warehouse": "<WAREHOUSE>", "query_timeout": 300}
    }
  }
}
```

**IMPORTANT**: Replace all placeholders (`<DATABASE>`, `<SCHEMA>`, `<WAREHOUSE>`) with actual values.

### Step 5: Create Agent

Use SQL DDL with FROM SPECIFICATION:

```python
import json

with open('agent_spec.json', 'r') as f:
    spec = json.load(f)

spec_str = json.dumps(spec, indent=2)

sql = f"""USE ROLE <ROLE>;
USE DATABASE <DATABASE>;
USE SCHEMA <SCHEMA>;

CREATE OR REPLACE AGENT <DATABASE>.<SCHEMA>.<AGENT_NAME>
  COMMENT = 'Autonomous data engineer agent for creating pipelines'
  PROFILE = '{{"display_name": "Data Engineer Agent"}}'
  FROM SPECIFICATION $$
{spec_str}
  $$;

SELECT 'Agent created successfully!' AS STATUS;
"""

with open('create_agent.sql', 'w') as f:
    f.write(sql)
```

Execute the SQL:

```bash
snow sql -f create_agent.sql -c <connection_name>
```

### Step 6: Verify Agent

```sql
-- Check agent exists
SHOW AGENTS LIKE '<AGENT_NAME>' IN SCHEMA <DATABASE>.<SCHEMA>;

-- Describe agent
DESCRIBE AGENT <DATABASE>.<SCHEMA>.<AGENT_NAME>;

-- Verify stored procedures
SHOW PROCEDURES IN SCHEMA <DATABASE>.<SCHEMA>;

-- Check tracker table
SELECT COUNT(*) FROM <DATABASE>.<SCHEMA>.DATA_PIPELINE_TRACKER;
```

### Step 7: Create Streamlit Dashboard

Create `streamlit_app.py`:

```python
import streamlit as st
import snowflake.snowpark as snowpark
from snowflake.snowpark.context import get_active_session
import json
import uuid
from datetime import datetime

st.set_page_config(page_title="Data Engineer Agent", page_icon="🔧", layout="wide")

st.title("🔧 Autonomous Data Engineer Agent")
st.markdown("Describe your data source, and I'll generate the DDL and set up your pipeline automatically.")

# Get Snowflake session
try:
    session = get_active_session()
except:
    import os
    from snowflake import connector
    conn = connector.connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "default")
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

# Initialize session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "thread_id" not in st.session_state:
    st.session_state.thread_id = None

def call_agent(message: str, thread_id: str = None):
    """Call the Cortex Agent"""
    if not thread_id:
        thread_result = session.sql("SELECT SYSTEM$CREATE_CORTEX_THREAD('data_engineer_app')").collect()
        thread_id = thread_result[0][0]
        st.session_state.thread_id = thread_id
    
    sql = f"""
    SELECT SYSTEM$RUN_CORTEX_AGENT(
        '<DATABASE>.<SCHEMA>.<AGENT_NAME>',
        '{thread_id}',
        PARSE_JSON('{json.dumps({"messages": [{"role": "user", "content": message}]})}')
    )
    """
    
    result = session.sql(sql).collect()
    return json.loads(result[0][0])

# Layout
col1, col2 = st.columns([2, 1])

with col1:
    st.subheader("💬 Chat with Agent")
    
    chat_container = st.container(height=500)
    with chat_container:
        for msg in st.session_state.messages:
            with st.chat_message(msg["role"]):
                st.markdown(msg["content"])
    
    if prompt := st.chat_input("Describe your data source (e.g., 'I have CSV files in s3://my-bucket/data/')"):
        st.session_state.messages.append({"role": "user", "content": prompt})
        
        with chat_container:
            with st.chat_message("user"):
                st.markdown(prompt)
            
            with st.chat_message("assistant"):
                with st.spinner("Agent is working..."):
                    response = call_agent(prompt, st.session_state.thread_id)
                    
                    if "content" in response:
                        content = response["content"]
                        if isinstance(content, list):
                            content = content[0].get("text", str(content))
                        st.markdown(content)
                        st.session_state.messages.append({"role": "assistant", "content": content})
                    else:
                        error_msg = f"Unexpected response format: {response}"
                        st.error(error_msg)
                        st.session_state.messages.append({"role": "assistant", "content": error_msg})

with col2:
    st.subheader("📊 Pipeline Tracker")
    
    tab1, tab2 = st.tabs(["Recent Pipelines", "Quick Setup"])
    
    with tab1:
        try:
            pipelines = session.sql("""
                SELECT 
                    PIPELINE_ID,
                    DATA_SOURCE_TYPE,
                    STATUS,
                    CREATED_AT,
                    TABLE_NAME
                FROM <DATABASE>.<SCHEMA>.DATA_PIPELINE_TRACKER
                ORDER BY CREATED_AT DESC
                LIMIT 10
            """).collect()
            
            if pipelines:
                for pipeline in pipelines:
                    status_emoji = "✅" if pipeline['STATUS'] == 'SUCCESS' else "❌"
                    with st.expander(f"{status_emoji} {pipeline['PIPELINE_ID'][:20]}..."):
                        st.text(f"Type: {pipeline['DATA_SOURCE_TYPE']}")
                        st.text(f"Status: {pipeline['STATUS']}")
                        st.text(f"Table: {pipeline['TABLE_NAME']}")
                        st.text(f"Created: {pipeline['CREATED_AT']}")
            else:
                st.info("No pipelines created yet")
        except Exception as e:
            st.warning(f"Could not load pipelines: {e}")
    
    with tab2:
        st.markdown("### Quick Setup Form")
        
        cloud = st.selectbox("Cloud Provider", ["AWS S3", "Azure", "GCS"])
        url = st.text_input("Storage URL", placeholder="s3://bucket/path/")
        format_type = st.selectbox("File Format", ["CSV", "JSON", "Parquet", "Avro", "ORC"])
        
        if st.button("🚀 Generate Setup", use_container_width=True):
            quick_prompt = f"Set up a pipeline for {cloud} at {url} with {format_type} files"
            st.session_state.messages.append({"role": "user", "content": quick_prompt})
            st.rerun()

# Sidebar
st.sidebar.title("ℹ️ About")
st.sidebar.markdown("""
This autonomous data engineer agent can:

- ✨ Generate storage integrations
- 📁 Create file formats  
- 🌐 Set up external stages
- 📊 Build external tables
- ⚡ Execute and track pipelines

**Supported:**
- AWS S3, Azure, GCS
- CSV, JSON, Parquet, Avro, ORC
""")

st.sidebar.markdown("---")
if st.sidebar.button("🔄 Clear Chat"):
    st.session_state.messages = []
    st.session_state.thread_id = None
    st.rerun()

st.sidebar.markdown("---")
st.sidebar.caption(f"Agent: <DATABASE>.<SCHEMA>.<AGENT_NAME>")
```

**IMPORTANT**: Replace all placeholders with actual values.

### Step 8: Create SPCS Deployment Files

#### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY streamlit_app.py .

EXPOSE 8501

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

ENTRYPOINT ["streamlit", "run", "streamlit_app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

#### requirements.txt

```
streamlit==1.40.0
snowflake-snowpark-python==1.25.0
snowflake-connector-python[pandas]==3.12.0
```

#### deploy.sh

```bash
#!/bin/bash

set -e

echo "🔧 Building and Deploying Data Engineer Agent to SPCS..."

echo "Step 1: Create image repository"
snow sql -q "
USE ROLE <ROLE>;
USE DATABASE <DATABASE>;
USE SCHEMA <SCHEMA>;

CREATE IMAGE REPOSITORY IF NOT EXISTS DATA_ENGINEER_REPO;
" -c <connection>

echo "Step 2: Get repository URL"
REPO_URL=$(snow sql -q "SHOW IMAGE REPOSITORIES IN SCHEMA <DATABASE>.<SCHEMA>;" -c <connection> --format json | python3 -c "
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
snow spcs image-registry login -c <connection>

echo "Step 6: Push image"
docker push $REPO_URL/data_engineer_agent:latest

echo "Step 7: Create compute pool"
snow sql -q "
CREATE COMPUTE POOL IF NOT EXISTS DATA_ENGINEER_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 3600;
" -c <connection>

echo "Step 8: Create service"
snow sql -q "
CREATE SERVICE IF NOT EXISTS DATA_ENGINEER_SERVICE
  IN COMPUTE POOL DATA_ENGINEER_POOL
  FROM SPECIFICATION \$\$
spec:
  containers:
  - name: data-engineer-agent
    image: $REPO_URL/data_engineer_agent:latest
  endpoints:
  - name: streamlit
    port: 8501
    public: true
\$\$;
" -c <connection>

echo "✅ Deployment complete!"
echo ""
echo "To get the service endpoint URL, run:"
echo "  snow sql -q \"SHOW ENDPOINTS IN SERVICE DATA_ENGINEER_SERVICE;\" -c <connection>"
```

Make executable: `chmod +x deploy.sh`

Replace `<connection>`, `<ROLE>`, `<DATABASE>`, `<SCHEMA>` with actual values.

## Testing

### Test Agent via SQL

```sql
-- Create a thread
SELECT SYSTEM$CREATE_CORTEX_THREAD('test_session');
-- Copy the returned thread_id

-- Send a message
SELECT SYSTEM$RUN_CORTEX_AGENT(
    '<DATABASE>.<SCHEMA>.<AGENT_NAME>',
    '<thread_id>',
    PARSE_JSON('{"messages": [{"role": "user", "content": "What can you help me with?"}]}')
);
```

### Test Streamlit Locally

```bash
SNOWFLAKE_CONNECTION_NAME=<connection> streamlit run streamlit_app.py
```

### Deploy to SPCS

```bash
./deploy.sh
```

## Best Practices

1. **Tool Order Matters**: Always create stored procedures before creating the agent
2. **Quote Escaping**: In EXECUTE_DDL_AND_TRACK, escape single quotes in JSON: `.replace("'", "''")`
3. **Agent Specification**: Use `FROM SPECIFICATION $$..$$` syntax, not CREATE AGENT with inline JSON
4. **Test Tools Independently**: Verify each stored procedure works before adding to agent
5. **Warehouse Selection**: Use appropriate warehouse size for tool execution
6. **Error Handling**: Tools should return error messages, not raise exceptions
7. **DDL Review**: Agent should always show DDL to user before executing
8. **Tracking**: Always log pipeline creation to tracker table

### Snowflake Stage Query Best Practices

9. **Never use SELECT * on stages**: Always use positional notation ($1, $2, $3...)
   ```python
   # ❌ WRONG
   query = f"SELECT * FROM @{stage_name} (FILE_FORMAT => {format_name})"
   
   # ✅ CORRECT
   query = f"SELECT $1, $2, $3, $4, $5 FROM @{stage_name} (FILE_FORMAT => {format_name})"
   ```

10. **Use INFER_SCHEMA before building queries**: Determine column count programmatically
    ```python
    # Get column count from INFER_SCHEMA
    schema_result = session.sql(f"""
        SELECT * FROM TABLE(
          INFER_SCHEMA(
            LOCATION => '@{stage_name}',
            FILE_FORMAT => '{format_name}'
          )
        )
    """).collect()
    
    num_columns = len(schema_result)
    
    # Build positional SELECT
    columns = ", ".join([f"${i+1}" for i in range(num_columns)])
    query = f"SELECT {columns} FROM @{stage_name} (FILE_FORMAT => {format_name})"
    ```

11. **CSV File Formats**: Always set `SKIP_HEADER = 1` for files with header rows
    ```sql
    CREATE OR REPLACE FILE FORMAT CSV_FORMAT
      TYPE = CSV
      SKIP_HEADER = 1        -- Critical for CSV files with headers
      FIELD_DELIMITER = ','
      ESCAPE = NONE
      PARSE_HEADER = false;  -- Set to true if you want to parse column names
    ```

### External Table Best Practices

12. **Prefer staging tables over external tables** when:
    - File paths contain spaces or special characters
    - Need guaranteed data availability
    - Performance is critical (staging tables are faster)
    
    ```sql
    -- Instead of external table
    CREATE OR REPLACE TABLE STAGING_TABLE AS
    SELECT $1, $2, $3, $4, $5
    FROM @MY_STAGE (FILE_FORMAT => MY_FORMAT);
    ```

13. **Always verify stage contents before creating tables**:
    ```sql
    -- Check files exist
    LIST @MY_STAGE;
    
    -- Test data access
    SELECT $1, $2, $3 FROM @MY_STAGE (FILE_FORMAT => MY_FORMAT) LIMIT 10;
    ```

14. **Provide both query options in UI**: Give users choice between external table and direct stage queries
    - External tables: Better for structured, repeatable queries
    - Stage queries: Better for ad-hoc exploration and troubleshooting

### Streamlit Development Best Practices

15. **Multi-page app structure**: Use `pages/` directory for automatic routing
    ```
    streamlit_app.py        # Home page
    pages/
      Data_Preview.py       # Auto-routes to /Data_Preview
      Pipeline_Tracker.py   # Auto-routes to /Pipeline_Tracker
    ```

16. **Page naming convention**: Filename becomes page title
    - `Data_Preview.py` → "Data Preview" (underscores become spaces)
    - Use `st.set_page_config(page_title="...")` for custom titles

17. **Session initialization pattern**: Always use try/except for Snowflake connection
    ```python
    try:
        session = get_active_session()  # Works in SPCS/SiS
    except:
        # Fallback for local development
        import os
        from snowflake.connector import connect
        conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "default")
        from snowflake.snowpark import Session
        session = Session.builder.configs({"connection": conn}).create()
    ```

18. **Always set database/schema/warehouse context**:
    ```python
    session.sql("USE DATABASE MY_DB").collect()
    session.sql("USE SCHEMA PUBLIC").collect()
    session.sql("USE WAREHOUSE MY_WH").collect()
    ```

19. **Error handling in UI**: Wrap queries in try/except and show user-friendly messages
    ```python
    try:
        result = session.sql(query).collect()
        if result:
            st.success(f"Found {len(result)} rows")
            st.dataframe(result)
        else:
            st.warning("No data returned")
    except Exception as e:
        st.error(f"Error: {str(e)}")
    ```

## Common Issues

### Issue: Agent Creation Fails with "syntax error"
**Solution**: Use `FROM SPECIFICATION $$...$$` syntax, not inline JSON

### Issue: Tool not found
**Solution**: Verify stored procedures exist before creating agent:
```sql
SHOW PROCEDURES IN SCHEMA <DATABASE>.<SCHEMA>;
```

### Issue: Agent doesn't respond
**Solution**: Check warehouse is running and agent has proper tool_resources configuration

### Issue: DDL execution fails
**Solution**: Verify user has proper cloud provider IAM roles configured

### Issue: Streamlit can't connect
**Solution**: Set `SNOWFLAKE_CONNECTION_NAME` environment variable

### Issue: Stage query fails with "SELECT with no columns"
**Problem**: Using `SELECT *` on Snowflake stages
```sql
-- ❌ WRONG - This fails
SELECT * FROM @MY_STAGE (FILE_FORMAT => MY_FORMAT);
```

**Root Cause**: Snowflake stages don't have named columns, so `SELECT *` is invalid syntax.

**Solution**: Use positional notation with $1, $2, $3, etc.
```sql
-- ✅ CORRECT - Use positional notation
SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
FROM @MY_STAGE (FILE_FORMAT => MY_FORMAT)
LIMIT 100;
```

**Best Practice**: Use `INFER_SCHEMA` first to determine number of columns:
```sql
SELECT * FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@MY_STAGE',
    FILE_FORMAT => 'MY_FORMAT'
  )
);
```
Then count the columns and generate the appropriate positional SELECT.

### Issue: External table queries return no data
**Problem**: External table created but queries return empty results, even when stage has data

**Common Causes**:
1. **File path contains spaces or special characters**
   - External tables may fail silently with certain file path patterns
   - Example: `s3://bucket/folder/My File Name.csv` 
   
2. **LOCATION specification mismatch**
   - External table LOCATION must exactly match file path in stage
   - Trailing slashes matter: `/folder/` vs `/folder`

3. **File format parameters incorrect**
   - CSV files with headers need `SKIP_HEADER = 1`
   - Without this, data may be misaligned or empty

**Solution 1**: Create a regular staging table instead
```sql
-- Instead of external table, use regular table with COPY INTO
CREATE OR REPLACE TABLE STAGING_TABLE AS
SELECT $1, $2, $3, $4, $5  -- positional columns
FROM @MY_STAGE
(FILE_FORMAT => MY_FORMAT);
```

**Solution 2**: Fix file format and location
```sql
-- Ensure file format has correct parameters
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_DELIMITER = ','
  ESCAPE = NONE;

-- Verify files in stage
LIST @MY_STAGE;

-- Create external table with exact LOCATION
CREATE OR REPLACE EXTERNAL TABLE MY_TABLE
  WITH LOCATION = @MY_STAGE
  FILE_FORMAT = CSV_FORMAT;
```

**Solution 3**: Query stage directly for troubleshooting
```sql
-- This always works - bypasses external table issues
SELECT $1, $2, $3 
FROM @MY_STAGE
(FILE_FORMAT => CSV_FORMAT)
LIMIT 10;
```

### Issue: Streamlit page title doesn't match expected name
**Problem**: Page shows "streamlit app" instead of custom title

**Root Cause**: Streamlit auto-generates page titles from Python filename
- Filename: `Data_Preview.py` → Page title: "Data Preview"
- Underscores become spaces
- First letter capitalized

**Solution**: 
1. Rename file to match desired title (e.g., `Home.py` → "Home")
2. Or use `st.set_page_config(page_title="Custom Title")` at the very top of the script

## Example Workflow

User: "I have CSV files in s3://my-bucket/sales/ with columns: order_id NUMBER, customer_name VARCHAR, amount DECIMAL, order_date DATE"

Agent will:
1. Ask for AWS IAM role ARN
2. Call `generate_storage_integration` → Generate DDL
3. Call `generate_file_format` → Generate CSV format DDL
4. Call `generate_external_stage` → Generate stage DDL
5. Call `generate_external_table` → Generate table DDL with specified columns
6. Show all DDL to user for review
7. When approved, call `execute_pipeline_ddl` → Execute and track
8. Respond: "✅ Pipeline created successfully!"

## Deliverables Checklist

- [ ] 5 stored procedures created
- [ ] Pipeline tracker table created
- [ ] Agent specification JSON created
- [ ] Agent created and verified
- [ ] Streamlit dashboard created
- [ ] Dockerfile created
- [ ] requirements.txt created
- [ ] deploy.sh script created
- [ ] README.md with documentation
- [ ] Test script created
- [ ] Agent tested via SQL
- [ ] Streamlit tested locally
- [ ] (Optional) Deployed to SPCS

## Key Learnings

1. **Create tools before agent**: Stored procedures must exist before referencing them in agent
2. **Use SQL DDL**: `CREATE AGENT FROM SPECIFICATION` is the correct syntax
3. **Escape quotes in JSON**: When inserting JSON strings into SQL, escape single quotes
4. **Tool descriptions matter**: Good descriptions help the LLM select appropriate tools
5. **Agent instructions are critical**: Clear orchestration instructions ensure correct tool ordering
6. **Response instructions improve UX**: Formatting guidelines make agent responses clearer
7. **Budget settings**: Set appropriate token and time budgets for complex workflows
8. **Test incrementally**: Verify each component before moving to the next

### Critical Snowflake Stage Learnings

9. **SELECT * doesn't work on stages**: This is a fundamental Snowflake limitation
   - Stages have no named columns, only positional references
   - Always use $1, $2, $3... notation
   - Error message: "SELECT with no columns"

10. **INFER_SCHEMA is essential**: Use it to discover data structure before writing queries
    - Returns column names, types, and order
    - Helps determine how many $N columns to select
    - Works for CSV, JSON, Parquet, and other formats

11. **External tables can fail silently**: Don't rely solely on external tables
    - File paths with spaces cause issues
    - LOCATION mismatches return empty results
    - Always provide direct stage query as backup option

12. **Staging tables are more reliable**: Convert stage data to regular tables when possible
    - Better performance
    - Avoid file path issues
    - Support SELECT * syntax
    - Easier to query and join

### Streamlit Multi-Page App Learnings

13. **Filename determines page title**: Streamlit auto-generates titles from filenames
    - Underscores become spaces
    - First letter capitalized
    - Can override with st.set_page_config()

14. **Session management in multi-page apps**: Each page needs its own session initialization
    - Use try/except pattern for compatibility
    - Set database/schema/warehouse context on every page
    - Environment variable for connection selection

15. **UI feedback is critical**: Always show query results immediately
    - Success messages with row counts
    - Error messages with details
    - Data preview with dataframes
    - Clear button labels and descriptions

### Debugging Workflow Learnings

16. **Test both data access methods**: Always provide multiple ways to access data
    - External table queries
    - Direct stage queries
    - Staging table queries (most reliable)

17. **Read error messages carefully**: Snowflake errors are usually specific
    - "SELECT with no columns" → using SELECT * on stage
    - "Object does not exist" → check database/schema context
    - Empty results → check file format, location, or use staging table

18. **Verify in browser**: Actually click buttons and test the UI
    - Code changes aren't enough
    - Must refresh browser after file edits
    - Check success/error messages appear correctly
    - Verify data displays as expected

19. **File format parameters matter**: CSV files need specific settings
    - SKIP_HEADER = 1 for files with headers
    - FIELD_DELIMITER must match actual delimiter
    - ESCAPE = NONE for simple CSV files
    - PARSE_HEADER impacts column naming

## Complete Data Preview Implementation Example

Based on real-world debugging experience, here's a complete Data Preview page that handles all edge cases:

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Session initialization with fallback
try:
    session = get_active_session()
except:
    import os
    from snowflake.connector import connect
    conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "pm")
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

# Set context
session.sql("USE DATABASE LEILA_APP").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("USE WAREHOUSE LEILAAPP").collect()

st.title("📊 Data Preview")

# Get pipeline info
pipeline_result = session.sql("""
    SELECT 
        PIPELINE_ID,
        TABLE_NAME,
        STAGE_NAME,
        FILE_FORMAT_NAME,
        STATUS
    FROM DATA_PIPELINE_TRACKER
    ORDER BY CREATED_AT DESC
    LIMIT 1
""").collect()

if not pipeline_result:
    st.error("No pipelines found")
    st.stop()

pipeline = pipeline_result[0].asDict()

# Tabs for different query methods
tab1, tab2, tab3 = st.tabs(["External Table", "Stage Data", "Staging Table"])

with tab1:
    st.subheader("Query External Table")
    limit_ext = st.number_input("Limit rows (External Table)", 10, 1000, 100, key="limit_ext")
    
    if st.button("🔍 Query External Table", key="query_external"):
        with st.spinner("Querying external table..."):
            try:
                result = session.sql(f"""
                    SELECT * FROM LEILA_APP.PUBLIC.{pipeline['TABLE_NAME']}
                    LIMIT {limit_ext}
                """).collect()
                
                if result:
                    st.success(f"Found {len(result)} rows")
                    st.dataframe(result, use_container_width=True)
                else:
                    st.warning("External table query returned no data. Try Stage Data tab.")
            except Exception as e:
                st.error(f"Error: {str(e)}")
                st.info("💡 Try the 'Stage Data' or 'Staging Table' tabs instead")

with tab2:
    st.subheader("Query Stage Directly")
    st.info("Using positional notation ($1, $2, $3...) to query stage")
    
    limit_stage = st.number_input("Limit rows (Stage)", 10, 1000, 100, key="limit_stage")
    
    # First, use INFER_SCHEMA to get column count
    if st.button("🔍 Query Stage Directly", key="query_stage"):
        with st.spinner("Querying stage..."):
            try:
                # Get schema info
                schema_result = session.sql(f"""
                    SELECT * FROM TABLE(
                      INFER_SCHEMA(
                        LOCATION => '@LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}',
                        FILE_FORMAT => 'LEILA_APP.PUBLIC.{pipeline['FILE_FORMAT_NAME']}'
                      )
                    )
                """).collect()
                
                num_columns = len(schema_result)
                st.info(f"Detected {num_columns} columns in file")
                
                # Build positional SELECT
                columns = ", ".join([f"${i+1}" for i in range(num_columns)])
                
                result = session.sql(f"""
                    SELECT {columns}
                    FROM @LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}
                    (FILE_FORMAT => LEILA_APP.PUBLIC.{pipeline['FILE_FORMAT_NAME']})
                    LIMIT {limit_stage}
                """).collect()
                
                if result:
                    st.success(f"Found {len(result)} rows")
                    st.dataframe(result, use_container_width=True)
                    
                    st.markdown("### 📊 Column Info")
                    st.write(f"Total columns: {len(result[0].asDict().keys())}")
                    st.write("Column names:", list(result[0].asDict().keys()))
                else:
                    st.warning("No data returned from stage")
            except Exception as e:
                st.error(f"Error querying stage: {str(e)}")

with tab3:
    st.subheader("Query Staging Table (Most Reliable)")
    st.info("Uses a regular Snowflake table - supports SELECT * and fastest performance")
    
    limit_staging = st.number_input("Limit rows (Staging Table)", 10, 1000, 100, key="limit_staging")
    
    if st.button("🔍 Query Staging Table", key="query_staging"):
        with st.spinner("Querying staging table..."):
            try:
                # Check if staging table exists
                staging_table_name = f"STAGING_{pipeline['PIPELINE_ID']}"
                
                # Try to query it
                result = session.sql(f"""
                    SELECT * FROM LEILA_APP.PUBLIC.{staging_table_name}
                    LIMIT {limit_staging}
                """).collect()
                
                if result:
                    st.success(f"Found {len(result)} rows")
                    st.dataframe(result, use_container_width=True)
                else:
                    st.warning("No data in staging table")
            except Exception as e:
                # Table doesn't exist, create it
                st.warning(f"Staging table doesn't exist. Creating it now...")
                try:
                    # Get column count first
                    schema_result = session.sql(f"""
                        SELECT * FROM TABLE(
                          INFER_SCHEMA(
                            LOCATION => '@LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}',
                            FILE_FORMAT => 'LEILA_APP.PUBLIC.{pipeline['FILE_FORMAT_NAME']}'
                          )
                        )
                    """).collect()
                    
                    num_columns = len(schema_result)
                    columns = ", ".join([f"${i+1}" for i in range(num_columns)])
                    
                    # Create staging table
                    session.sql(f"""
                        CREATE OR REPLACE TABLE LEILA_APP.PUBLIC.{staging_table_name} AS
                        SELECT {columns}
                        FROM @LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}
                        (FILE_FORMAT => LEILA_APP.PUBLIC.{pipeline['FILE_FORMAT_NAME']})
                    """).collect()
                    
                    st.success("Staging table created! Click again to query.")
                except Exception as create_error:
                    st.error(f"Error creating staging table: {str(create_error)}")
```

### Key Features of This Implementation:

1. **Three data access methods**: External table, direct stage query, and staging table
2. **Dynamic column detection**: Uses INFER_SCHEMA to build queries
3. **Error recovery**: Suggests alternatives when one method fails
4. **Auto-creation**: Creates staging table if it doesn't exist
5. **User-friendly feedback**: Clear success/warning/error messages
6. **Performance options**: Users can choose speed vs flexibility

## Troubleshooting Workflow

When debugging data access issues, follow this systematic approach:

### Step 1: Verify Stage Contents
```sql
-- List files in stage
LIST @MY_STAGE;

-- Check file size and path
-- Look for: spaces in filenames, special characters, correct location
```

### Step 2: Test File Format
```sql
-- Verify file format exists and has correct settings
DESC FILE FORMAT MY_FORMAT;

-- Key settings to check:
-- - SKIP_HEADER = 1 (for CSV with headers)
-- - FIELD_DELIMITER matches actual delimiter
-- - TYPE matches file type (CSV, JSON, PARQUET, etc.)
```

### Step 3: Infer Schema
```sql
-- Discover data structure
SELECT * FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@MY_STAGE',
    FILE_FORMAT => 'MY_FORMAT'
  )
);

-- This tells you:
-- - Number of columns
-- - Column names (if PARSE_HEADER = true)
-- - Column types
-- - Any parsing issues
```

### Step 4: Test Direct Stage Query
```sql
-- Use positional notation based on INFER_SCHEMA results
SELECT $1, $2, $3, $4, $5
FROM @MY_STAGE
(FILE_FORMAT => MY_FORMAT)
LIMIT 10;

-- If this fails:
-- - Check file format parameters
-- - Verify files aren't corrupted
-- - Check IAM roles for cloud storage
```

### Step 5: Check External Table
```sql
-- Verify external table definition
DESC EXTERNAL TABLE MY_EXTERNAL_TABLE;

-- Query it
SELECT * FROM MY_EXTERNAL_TABLE LIMIT 10;

-- If empty but stage query works:
-- - File path in LOCATION may not match stage files
-- - Consider using staging table instead
```

### Step 6: Create Staging Table (If Needed)
```sql
-- Most reliable option - copy data to regular table
CREATE OR REPLACE TABLE MY_STAGING_TABLE AS
SELECT $1 as col1, $2 as col2, $3 as col3
FROM @MY_STAGE
(FILE_FORMAT => MY_FORMAT);

-- Benefits:
-- - Supports SELECT *
-- - Faster queries
-- - No file path issues
-- - Can add indexes, constraints, etc.
```

### Step 7: Verify in Streamlit UI
1. Refresh browser to load latest code
2. Click each query button
3. Check for success messages
4. Verify data displays correctly
5. Test error scenarios

## References

- [Cortex Agents Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [External Tables Documentation](https://docs.snowflake.com/en/user-guide/tables-external-intro)
- [Snowpark Container Services Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
