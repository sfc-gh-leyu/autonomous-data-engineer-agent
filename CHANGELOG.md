# Changelog

All notable changes to the Autonomous Data Engineer Agent project will be documented in this file.

## [2.1.0] - 2026-02-02

### 🔄 Changed: Placeholders for Universal Use

Made the repository universally reusable by replacing all hardcoded names with generic placeholders.

#### Placeholder Replacements

All specific object names have been replaced with placeholders:
- `LEILA_APP` → `<DATABASE>`
- `LEILAAPP` → `<WAREHOUSE>`
- `DATA_ENGINEER_AGENT` → `<AGENT_NAME>`
- `pm` → `<connection>`
- `/Users/leyu/...` → `<project_directory>`

#### Files Updated

13 files modified with placeholder replacements:
- All documentation files (*.md)
- All SQL scripts (*.sql)
- All Python files (*.py)
- All shell scripts (*.sh)

#### Documentation Enhancements

- Added placeholder notes to SKILL.md, README.md, and QUICK_REFERENCE.md
- Created comprehensive PLACEHOLDER_GUIDE.md explaining:
  - Complete placeholder reference table
  - How to replace placeholders (3 methods)
  - Configuration examples for different teams
  - Verification checklist
  - Common patterns in SQL, Python, and shell

#### Benefits

✅ **Reusable**: Anyone can use without manual cleanup  
✅ **Secure**: No hardcoded credentials or account information  
✅ **Flexible**: Easy to adapt to different naming conventions  
✅ **Educational**: Clear separation between template and implementation

## [2.0.0] - 2026-02-01

### 🎉 Major Update: Production-Tested Patterns

This release incorporates real-world debugging experience and production-validated patterns from building and deploying the autonomous data engineer agent.

### Added

#### Documentation
- **QUICK_REFERENCE.md**: One-page cheat sheet with critical patterns and common solutions
- **SKILL_UPDATE_SUMMARY.md**: Detailed documentation of all improvements and lessons learned
- **examples/pages/Data_Preview.py**: Production-ready data preview implementation

#### SKILL.md Enhancements
- Extended "Common Issues" section with 3 major new issues:
  - Stage query fails with "SELECT with no columns"
  - External table queries return no data  
  - Streamlit page title issues
  
- Expanded "Best Practices" from 8 to 19 items:
  - Snowflake stage query patterns (#9-11)
  - External table best practices (#12-14)
  - Streamlit development patterns (#15-19)
  
- Expanded "Key Learnings" from 8 to 19 items:
  - Critical Snowflake stage limitations (#9-12)
  - Multi-page Streamlit app patterns (#13-15)
  - Production debugging workflows (#16-19)
  
- **Complete Data Preview Implementation** (190+ lines):
  - Three query methods (external table, direct stage, staging table)
  - Dynamic column detection using INFER_SCHEMA
  - Error recovery with automatic fallbacks
  - User-friendly feedback messages
  
- **7-Step Troubleshooting Workflow**:
  - Systematic debugging process
  - SQL commands for each step
  - What to check and why

### Changed

#### README.md
- Added update banner highlighting February 2026 improvements
- Reorganized documentation section with clear hierarchy
- Enhanced troubleshooting section with quick fixes
- Added references to new documentation files

#### SKILL.md Size
- Before: 1,033 lines
- After: 1,569 lines
- Added: 536 lines of production-tested content

### Fixed

#### Critical Snowflake Stage Query Issues
- **SELECT * on stages**: Documented that this always fails
  - Error: "SELECT with no columns"
  - Solution: Use positional notation ($1, $2, $3...)
  - Implementation: Use INFER_SCHEMA to detect columns dynamically

#### External Table Reliability
- **File paths with spaces**: External tables fail silently
  - Solution: Create staging tables as fallback
  - Pattern: Provide multiple query options in UI
  
#### CSV File Format
- **Missing headers**: SKIP_HEADER parameter is critical
  - Default should be SKIP_HEADER = 1 for CSV files
  - Document PARSE_HEADER for column naming

### Validated

All patterns have been tested in production:
- ✅ Stage queries with positional notation work correctly
- ✅ INFER_SCHEMA accurately detects column structure
- ✅ Staging tables provide reliable data access
- ✅ Multi-page Streamlit apps with proper session management
- ✅ Error handling with user-friendly messages

### Impact

Future implementations will:
- Start with correct patterns (no SELECT * on stages)
- Include INFER_SCHEMA in standard workflow
- Provide multiple data access methods
- Have comprehensive troubleshooting guides
- Use production-ready code examples

### Documentation Stats

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| SKILL.md | Complete guide | 1,569 | Updated |
| QUICK_REFERENCE.md | Cheat sheet | 321 | New |
| SKILL_UPDATE_SUMMARY.md | Change details | 490 | New |
| examples/Data_Preview.py | Working code | 270+ | New |

### Technical Details

#### Snowflake Stage Query Pattern
```python
# Get column count dynamically
schema = session.sql(f"""
    SELECT * FROM TABLE(
      INFER_SCHEMA(
        LOCATION => '@{stage_name}',
        FILE_FORMAT => '{format_name}'
      )
    )
""").collect()

num_cols = len(schema)
cols = ", ".join([f"${i+1}" for i in range(num_cols)])

# Query with positional notation
result = session.sql(f"""
    SELECT {cols}
    FROM @{stage_name}
    (FILE_FORMAT => {format_name})
    LIMIT 100
""").collect()
```

#### File Format Template
```sql
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1        -- Critical for CSV with headers
  FIELD_DELIMITER = ','
  ESCAPE = NONE
  PARSE_HEADER = false;
```

#### Streamlit Session Pattern
```python
try:
    session = get_active_session()
except:
    import os
    from snowflake.connector import connect
    conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME"))
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

# Always set context
session.sql("USE DATABASE MY_DB").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("USE WAREHOUSE MY_WH").collect()
```

## [1.0.0] - 2026-01-30

### Initial Release

- Cortex Agent with 5 custom tools
- Storage integration generation (AWS, Azure, GCS)
- File format creation (CSV, JSON, Parquet, Avro, ORC)
- External stage setup
- External table generation
- Pipeline tracking table
- Streamlit dashboard
- SPCS deployment configuration
- Complete documentation (SKILL.md, README.md, ARCHITECTURE.md)

---

**Legend**
- 🎉 Major feature
- ✨ Enhancement
- 🐛 Bug fix
- 📚 Documentation
- 🔧 Configuration
- ⚠️ Breaking change
