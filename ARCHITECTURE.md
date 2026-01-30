# Autonomous Data Engineer Agent - Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SNOWPARK CONTAINER SERVICES (SPCS)                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Streamlit Dashboard                         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────────────┐   │  │
│  │  │ Chat UI    │  │ Pipeline   │  │ Quick Setup Form    │   │  │
│  │  │            │  │ Tracker    │  │                      │   │  │
│  │  └────────────┘  └────────────┘  └──────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                               ▼                                      │
│                    Docker Container: data_engineer_agent:latest      │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ HTTPS/REST API
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SNOWFLAKE CORTEX AGENT                          │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │           LEILA_APP.PUBLIC.DATA_ENGINEER_AGENT               │  │
│  │                                                              │  │
│  │  Orchestration: Claude Sonnet (auto)                        │  │
│  │  Budget: 900s / 400K tokens                                 │  │
│  │                                                              │  │
│  │  Instructions:                                              │  │
│  │  • Gather data source requirements                          │  │
│  │  • Generate DDL in correct sequence                         │  │
│  │  • Review with user                                         │  │
│  │  • Execute and track                                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                               │                                      │
│                   ┌───────────┴───────────┐                         │
│                   ▼                       ▼                         │
│         ┌──────────────────┐    ┌──────────────────┐               │
│         │   Tool Selection  │    │  Response Gen    │               │
│         └──────────────────┘    └──────────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    │ Stored Procedure Calls
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CUSTOM TOOLS (Stored Procedures)                  │
│                     LEILA_APP.PUBLIC Schema                          │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  1. GENERATE_STORAGE_INTEGRATION_DDL                       │    │
│  │     ├─ AWS S3: IAM Role ARN + Allowed Locations           │    │
│  │     ├─ Azure: Tenant ID + Allowed Locations               │    │
│  │     └─ GCS: Allowed Locations                             │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  2. GENERATE_FILE_FORMAT_DDL                               │    │
│  │     ├─ CSV: delimiter, skip_header, trim_space            │    │
│  │     ├─ JSON: compression, trim_space                       │    │
│  │     ├─ Parquet: compression                                │    │
│  │     ├─ Avro: compression                                   │    │
│  │     └─ ORC: trim_space                                     │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  3. GENERATE_EXTERNAL_STAGE_DDL                            │    │
│  │     └─ URL + Storage Integration + File Format            │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  4. GENERATE_EXTERNAL_TABLE_DDL                            │    │
│  │     └─ Columns + Stage + Format + Partitioning            │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │  5. EXECUTE_DDL_AND_TRACK                                  │    │
│  │     └─ Execute DDL Array + Log to Tracker                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                               │                                      │
│                Execution on Warehouse: LEILAAPP                     │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    │ Write Results
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     DATA_PIPELINE_TRACKER Table                      │
│                     LEILA_APP.PUBLIC.DATA_PIPELINE_TRACKER           │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │ PIPELINE_ID           | Unique identifier                  │    │
│  │ CREATED_AT            | Timestamp                          │    │
│  │ DATA_SOURCE_TYPE      | Description (e.g., AWS_S3_LOGS)   │    │
│  │ INTEGRATION_NAME      | Storage integration created        │    │
│  │ STAGE_NAME            | External stage created             │    │
│  │ FILE_FORMAT_NAME      | File format created                │    │
│  │ TABLE_NAME            | External table created             │    │
│  │ STATUS                | SUCCESS / FAILED                   │    │
│  │ DDL_STATEMENTS        | JSON array of all DDL              │    │
│  │ EXECUTION_LOG         | JSON log of execution steps        │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                      WORKFLOW EXAMPLE: AWS S3                        │
│                                                                      │
│  1. User: "I have CSV files in s3://bucket/data/ with columns       │
│           id, name, date"                                           │
│                                                                      │
│  2. Agent → generate_storage_integration                            │
│     Input: AWS, s3://bucket/*, <IAM Role ARN>                       │
│     Output: CREATE STORAGE INTEGRATION ... DDL                      │
│                                                                      │
│  3. Agent → generate_file_format                                    │
│     Input: CSV, delimiter=',', skip_header=1                        │
│     Output: CREATE FILE FORMAT ... DDL                              │
│                                                                      │
│  4. Agent → generate_external_stage                                 │
│     Input: s3://bucket/data/, integration_name, format_name         │
│     Output: CREATE EXTERNAL STAGE ... DDL                           │
│                                                                      │
│  5. Agent → generate_external_table                                 │
│     Input: columns=[id NUMBER, name VARCHAR, date DATE], stage      │
│     Output: CREATE EXTERNAL TABLE ... DDL                           │
│                                                                      │
│  6. Agent shows all DDL to user for approval                        │
│                                                                      │
│  7. User approves                                                   │
│                                                                      │
│  8. Agent → execute_pipeline_ddl                                    │
│     Input: [integration_ddl, format_ddl, stage_ddl, table_ddl]     │
│     Output: Execution status + tracker entry                        │
│                                                                      │
│  9. Agent: "✅ Pipeline created! You can now query the data with:   │
│            SELECT * FROM <table_name>;"                             │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT FLOW                              │
│                                                                      │
│  Local Dev             SPCS Deployment            Cloud Storage     │
│  ┌──────────┐         ┌──────────────┐         ┌───────────────┐  │
│  │ Docker   │  push   │ Image Repo   │         │  AWS S3       │  │
│  │ Build    │────────>│ LEILA_APP.   │         │  Azure Blob   │  │
│  │          │         │ PUBLIC.DATA_ │         │  GCS          │  │
│  └──────────┘         │ ENGINEER_REP │         └───────────────┘  │
│                       │ O            │                 ▲           │
│                       └──────────────┘                 │           │
│                              │                         │           │
│                              ▼                         │           │
│                       ┌──────────────┐         ┌─────────────┐    │
│                       │ Compute Pool │         │ External    │    │
│                       │ DATA_        │         │ Tables      │    │
│                       │ ENGINEER_    │◄────────│ (Query)     │    │
│                       │ POOL         │         │             │    │
│                       └──────────────┘         └─────────────┘    │
│                              │                                     │
│                              ▼                                     │
│                       ┌──────────────┐                             │
│                       │ Service      │                             │
│                       │ DATA_        │                             │
│                       │ ENGINEER_    │                             │
│                       │ SERVICE      │                             │
│                       └──────────────┘                             │
│                              │                                     │
│                              ▼                                     │
│                       ┌──────────────┐                             │
│                       │ Public       │                             │
│                       │ Endpoint     │                             │
│                       │ (HTTPS)      │                             │
│                       └──────────────┘                             │
└─────────────────────────────────────────────────────────────────────┘

Legend:
────> Data/control flow
═════ Component boundary
▼     Directional flow
```

## Key Components:

1. **Streamlit Dashboard** (SPCS Container)
   - User interface
   - Chat with agent
   - Pipeline tracking
   - Quick setup forms

2. **Cortex Agent** (LEILA_APP.PUBLIC.DATA_ENGINEER_AGENT)
   - Orchestrates tool calls
   - Uses Claude Sonnet
   - Manages conversation context
   - Generates and reviews DDL

3. **Custom Tools** (5 Stored Procedures)
   - DDL generation for each component
   - Execution and tracking
   - Cloud-specific handling

4. **Pipeline Tracker** (Table)
   - Audit trail
   - Execution logs
   - Status tracking

5. **External Data** (Cloud Storage)
   - AWS S3, Azure, GCS
   - Multiple file formats
   - Queried via external tables

## Benefits:

✅ Natural language interface
✅ Automated DDL generation
✅ Multi-cloud support
✅ Full audit trail
✅ Production-ready deployment
✅ Scalable SPCS architecture
