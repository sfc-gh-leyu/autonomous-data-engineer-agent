USE ROLE ACCOUNTADMIN;
USE DATABASE <DATABASE>;
USE SCHEMA PUBLIC;

CREATE OR REPLACE AGENT <DATABASE>.PUBLIC.<AGENT_NAME>
  COMMENT = 'Autonomous data engineer agent for creating pipelines'
  PROFILE = '{"display_name": "Data Engineer Agent"}'
  FROM SPECIFICATION $$
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
              "enum": [
                "AWS",
                "S3",
                "AZURE",
                "GCS"
              ],
              "description": "Cloud provider: AWS/S3, AZURE, or GCS"
            },
            "storage_aws_role_arn": {
              "type": "string",
              "description": "AWS IAM role ARN (required for AWS). Example: arn:aws:iam::123456789012:role/SnowflakeRole"
            },
            "storage_allowed_locations": {
              "type": "array",
              "items": {
                "type": "string"
              },
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
          "required": [
            "integration_name",
            "cloud_provider",
            "storage_allowed_locations"
          ]
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
            "format_name": {
              "type": "string",
              "description": "Name for the file format (e.g., MY_CSV_FORMAT)"
            },
            "format_type": {
              "type": "string",
              "enum": [
                "CSV",
                "JSON",
                "PARQUET",
                "AVRO",
                "ORC"
              ],
              "description": "Type of file format"
            },
            "compression": {
              "type": "string",
              "enum": [
                "AUTO",
                "GZIP",
                "BZ2",
                "BROTLI",
                "ZSTD",
                "DEFLATE",
                "RAW_DEFLATE",
                "NONE"
              ],
              "description": "Compression type (default: AUTO)"
            },
            "field_delimiter": {
              "type": "string",
              "description": "Field delimiter for CSV files (default: ',')"
            },
            "skip_header": {
              "type": "integer",
              "description": "Number of header lines to skip (default: 0)"
            },
            "trim_space": {
              "type": "boolean",
              "description": "Whether to trim whitespace from fields (default: false)"
            },
            "error_on_column_count_mismatch": {
              "type": "boolean",
              "description": "Whether to error if column count doesn't match (default: true)"
            }
          },
          "required": [
            "format_name",
            "format_type"
          ]
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
            "stage_name": {
              "type": "string",
              "description": "Name for the external stage (e.g., MY_S3_STAGE)"
            },
            "url": {
              "type": "string",
              "description": "URL to cloud storage location. Examples: s3://bucket/path/, azure://account.blob.core.windows.net/container/, gcs://bucket/path/"
            },
            "storage_integration": {
              "type": "string",
              "description": "Name of the storage integration to use (recommended)"
            },
            "file_format": {
              "type": "string",
              "description": "Name of the file format to use (optional, can be specified later)"
            },
            "credentials": {
              "type": "string",
              "description": "Inline credentials string (alternative to storage integration, not recommended for production)"
            }
          },
          "required": [
            "stage_name",
            "url"
          ]
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
            "table_name": {
              "type": "string",
              "description": "Name for the external table (e.g., MY_EXTERNAL_TABLE)"
            },
            "stage_name": {
              "type": "string",
              "description": "Name of the external stage to use"
            },
            "file_format": {
              "type": "string",
              "description": "Name of the file format to use"
            },
            "columns": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "description": "Array of column definitions. Format: 'COLUMN_NAME TYPE'. Example: ['ID NUMBER', 'NAME VARCHAR', 'CREATED_DATE TIMESTAMP']"
            },
            "partition_by": {
              "type": "string",
              "description": "Partition expression (optional). Example: 'TO_DATE(CREATED_DATE)'"
            },
            "auto_refresh": {
              "type": "boolean",
              "description": "Whether to enable automatic metadata refresh (default: false)"
            }
          },
          "required": [
            "table_name",
            "stage_name",
            "file_format",
            "columns"
          ]
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
            "pipeline_id": {
              "type": "string",
              "description": "Unique identifier for this pipeline (use UUID or descriptive name)"
            },
            "data_source_type": {
              "type": "string",
              "description": "Type/description of the data source (e.g., 'AWS_S3_SALES_DATA', 'AZURE_LOGS')"
            },
            "ddl_statements": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "description": "Array of DDL statements to execute in order"
            }
          },
          "required": [
            "pipeline_id",
            "data_source_type",
            "ddl_statements"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "generate_storage_integration": {
      "type": "procedure",
      "identifier": "<DATABASE>.PUBLIC.GENERATE_STORAGE_INTEGRATION_DDL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "<WAREHOUSE>",
        "query_timeout": 300
      }
    },
    "generate_file_format": {
      "type": "procedure",
      "identifier": "<DATABASE>.PUBLIC.GENERATE_FILE_FORMAT_DDL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "<WAREHOUSE>",
        "query_timeout": 300
      }
    },
    "generate_external_stage": {
      "type": "procedure",
      "identifier": "<DATABASE>.PUBLIC.GENERATE_EXTERNAL_STAGE_DDL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "<WAREHOUSE>",
        "query_timeout": 300
      }
    },
    "generate_external_table": {
      "type": "procedure",
      "identifier": "<DATABASE>.PUBLIC.GENERATE_EXTERNAL_TABLE_DDL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "<WAREHOUSE>",
        "query_timeout": 300
      }
    },
    "execute_pipeline_ddl": {
      "type": "procedure",
      "identifier": "<DATABASE>.PUBLIC.EXECUTE_DDL_AND_TRACK",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "<WAREHOUSE>",
        "query_timeout": 300
      }
    }
  }
}
  $$;

SELECT 'Agent created successfully!' AS STATUS;
