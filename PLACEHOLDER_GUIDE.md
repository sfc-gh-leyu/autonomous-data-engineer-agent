# Placeholder Guide

## Overview

This repository uses placeholder notation to make the code and documentation reusable by anyone. All specific Snowflake object names, user names, and connection details have been replaced with generic placeholders.

## Placeholder Reference

When you see these placeholders in the code or documentation, replace them with your actual values:

### Snowflake Objects

| Placeholder | Replace With | Example |
|-------------|--------------|---------|
| `<DATABASE>` | Your database name | `MY_DATABASE` |
| `<SCHEMA>` | Your schema name | `PUBLIC` |
| `<WAREHOUSE>` | Your warehouse name | `COMPUTE_WH` |
| `<AGENT_NAME>` | Your agent name | `DATA_ENGINEER_AGENT` |
| `<ROLE>` | Your role name | `SYSADMIN` or `ACCOUNTADMIN` |

### Connections and Paths

| Placeholder | Replace With | Example |
|-------------|--------------|---------|
| `<connection>` | Your Snow CLI connection name | `myconn` |
| `<project_directory>` | Your local project path | `/Users/john/my-agent` |

### Pipeline Objects

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<STAGE_NAME>` | Stage name from pipeline tracker | `S3_STAGE_20260131_115633` |
| `<TABLE_NAME>` | Table name from pipeline tracker | `EXTERNAL_TABLE_20260131` |
| `<FILE_FORMAT_NAME>` | File format name | `CSV_FORMAT_20260131` |

## How to Replace Placeholders

### Method 1: Manual Replacement (Recommended)

As you work through the documentation and code, replace placeholders with your actual values on a case-by-case basis.

**Example:**

Before:
```sql
USE DATABASE <DATABASE>;
USE WAREHOUSE <WAREHOUSE>;
```

After:
```sql
USE DATABASE MY_DATA_LAB;
USE WAREHOUSE COMPUTE_WH;
```

### Method 2: Find and Replace

If you want to replace all occurrences at once, use find-and-replace in your editor:

```bash
# Example: Replace all <DATABASE> occurrences
find . -type f -name "*.md" -o -name "*.sql" -o -name "*.py" -exec sed -i 's/<DATABASE>/MY_DATABASE/g' {} +
```

⚠️ **Warning**: This will modify all files. Make sure to commit your current state first!

### Method 3: Environment Variables

For connection names, you can use environment variables instead of hardcoding:

```python
# Code already supports this pattern
conn = connect(
    connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "<connection>"
)
```

Then set the environment variable:
```bash
export SNOWFLAKE_CONNECTION_NAME=myconn
```

## Files with Placeholders

### Documentation Files
- `README.md` - Main documentation
- `SKILL.md` - Complete skill guide
- `QUICK_REFERENCE.md` - One-page cheat sheet
- `SKILL_UPDATE_SUMMARY.md` - Update documentation
- `DEPLOYMENT_SUMMARY.md` - Deployment guide
- `START_HERE.md` - Quick start guide

### Code Files
- `create_agent.sql` - Agent creation SQL
- `streamlit_app.py` - Main Streamlit app
- `examples/pages/Data_Preview.py` - Example data preview page
- `test_setup.py` - Test script

### Script Files
- `deploy.sh` - Deployment script
- `quickstart.sh` - Quick setup script

## Common Placeholder Patterns

### SQL Queries

```sql
-- Pattern in documentation
SELECT * FROM <DATABASE>.<SCHEMA>.<TABLE_NAME>;

-- Your implementation
SELECT * FROM ANALYTICS_DB.PUBLIC.SALES_DATA;
```

### Python Code

```python
# Pattern in documentation
session.sql("USE DATABASE <DATABASE>").collect()

# Your implementation
session.sql("USE DATABASE ANALYTICS_DB").collect()
```

### Shell Commands

```bash
# Pattern in documentation
snow sql -q "SHOW AGENTS;" -c <connection>

# Your implementation
snow sql -q "SHOW AGENTS;" -c prod_connection
```

## Configuration Examples

### Example 1: Data Science Team

```
<DATABASE> → DS_LAB
<WAREHOUSE> → DS_COMPUTE_WH
<AGENT_NAME> → DATA_PIPELINE_AGENT
<connection> → ds_prod
```

### Example 2: Analytics Team

```
<DATABASE> → ANALYTICS
<WAREHOUSE> → ANALYTICS_WH
<AGENT_NAME> → ETL_AGENT
<connection> → analytics_conn
```

### Example 3: Development Environment

```
<DATABASE> → DEV_DB
<WAREHOUSE> → DEV_WH
<AGENT_NAME> → DEV_AGENT
<connection> → dev
```

## Quick Setup Checklist

Before running any code or deployment scripts, make sure you've replaced:

- [ ] `<DATABASE>` in all SQL files
- [ ] `<WAREHOUSE>` in all SQL and Python files
- [ ] `<AGENT_NAME>` in create_agent.sql and documentation
- [ ] `<connection>` in deploy.sh and README.md
- [ ] `<project_directory>` in deployment paths

## Verification

After replacing placeholders, verify your configuration:

```sql
-- Test database access
USE DATABASE <YOUR_DATABASE>;
SHOW SCHEMAS;

-- Test warehouse
USE WAREHOUSE <YOUR_WAREHOUSE>;
SELECT CURRENT_WAREHOUSE();

-- Test agent (after creation)
DESCRIBE AGENT <YOUR_DATABASE>.PUBLIC.<YOUR_AGENT_NAME>;
```

## Need Help?

If you encounter issues with placeholders:

1. Check the [SKILL.md](SKILL.md) file for complete examples
2. Review the [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for patterns
3. See [README.md](README.md) for deployment instructions

## Why Placeholders?

This approach makes the repository:
- ✅ **Reusable**: Anyone can use it without manual cleanup
- ✅ **Secure**: No hardcoded credentials or specific account information
- ✅ **Flexible**: Easy to adapt to different naming conventions
- ✅ **Educational**: Clear separation between template and implementation

---

**Last Updated**: February 2, 2026  
**Version**: 2.1.0
