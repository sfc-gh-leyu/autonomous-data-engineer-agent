# Create Data Engineer Agent App Skill

## What is This?

This is a **reusable skill** for Cortex Code that automates the creation of data engineer agent apps in Snowflake.

## Quick Start

In any Cortex Code session, simply say:

```
"Create an autonomous data engineer agent"
```

The skill will guide you through the entire process.

## What the Skill Creates

When you use this skill, Cortex Code will create:

1. **5 Custom Tools** (Stored Procedures)
   - Storage integration generator
   - File format generator
   - External stage generator
   - External table generator
   - DDL executor and tracker

2. **Cortex Agent**
   - Fully configured with all tools
   - Intelligent orchestration
   - Natural language interface

3. **Pipeline Tracker**
   - Audit trail table
   - Execution logging
   - Status tracking

4. **Streamlit Dashboard**
   - Chat interface
   - Pipeline viewer
   - Quick setup forms

5. **SPCS Deployment**
   - Docker configuration
   - Deployment scripts
   - Service specification

## Example Usage

After the skill creates your agent, users can interact like this:

**User**: "I have CSV files in s3://my-bucket/sales/ with columns: order_id, customer_name, amount, order_date"

**Agent**: 
1. Asks for AWS IAM role
2. Generates all DDL
3. Shows for review
4. Executes on approval
5. Tracks in database

## Supported

**Cloud Providers**:
- AWS S3
- Azure Blob Storage
- Google Cloud Storage

**File Formats**:
- CSV
- JSON
- Parquet
- Avro
- ORC

## Skill Contents

- `SKILL.md` - Complete skill documentation (use this)
- `SKILL_SUMMARY.md` - What the skill provides
- `SKILL_README.md` - This file

## How It Works

1. **Requirements Gathering**: Skill asks for database, schema, agent name, etc.
2. **Component Creation**: Creates stored procedures in correct order
3. **Agent Configuration**: Builds agent specification with tools
4. **Agent Creation**: Uses proper SQL syntax to create agent
5. **Dashboard Creation**: Generates Streamlit UI
6. **Deployment Setup**: Creates Docker and SPCS files
7. **Verification**: Tests all components
8. **Documentation**: Generates comprehensive docs

## Key Features

✅ **Complete**: Everything from tools to deployment  
✅ **Tested**: Based on working implementation  
✅ **Documented**: Extensive inline documentation  
✅ **Reusable**: Template variables for customization  
✅ **Production-Ready**: Includes SPCS deployment

## Time Savings

- **Without Skill**: 2-4 hours to build from scratch
- **With Skill**: 10-15 minutes guided creation
- **Improvement**: ~90% time reduction

## Learning Captured

The skill includes critical learnings:
- Tool creation order (MUST create before agent)
- Proper agent creation syntax
- JSON escaping in SQL
- Tool design patterns
- Agent instruction best practices
- SPCS deployment workflow

## Files Generated

When you use the skill, you'll get:

```
YOUR_AGENT_NAME/
├── agent_spec.json         # Agent configuration
├── streamlit_app.py        # Dashboard
├── Dockerfile              # Container
├── requirements.txt        # Dependencies
├── deploy.sh              # Deployment script
├── create_agent.sql       # Agent creation SQL
├── test_setup.py          # Verification tests
├── README.md              # User documentation
├── ARCHITECTURE.md        # System design
└── DEPLOYMENT_SUMMARY.md  # Quick reference
```

## Customization

The skill uses template variables that you provide:
- `<DATABASE>` - Your database name
- `<SCHEMA>` - Your schema name
- `<AGENT_NAME>` - Your agent name
- `<ROLE>` - Your role name
- `<WAREHOUSE>` - Your warehouse name

## Prerequisites

- Snowflake account with Cortex enabled
- CREATE AGENT privilege
- CREATE PROCEDURE privilege
- Appropriate warehouse access

## Support

For issues or questions:
1. Check `SKILL.md` for detailed instructions
2. Review `ARCHITECTURE.md` for system design
3. See `DEPLOYMENT_SUMMARY.md` for troubleshooting

## Version

- **Created**: January 30, 2026
- **Cortex Code Version**: 1.0.0
- **Snowflake Features**: Cortex Agents, SPCS

## License

This skill is provided as a reference implementation for Snowflake customers.

---

**Ready to use!** Just mention "autonomous data engineer agent" in Cortex Code. 🚀
