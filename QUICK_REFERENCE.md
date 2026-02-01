# Quick Reference: Snowflake Data Access Patterns

## 🚨 Critical: Stage Query Syntax

### ❌ WRONG - This ALWAYS Fails
```sql
SELECT * 
FROM @MY_STAGE 
(FILE_FORMAT => MY_FORMAT);
```
**Error**: "SELECT with no columns"

### ✅ CORRECT - Use Positional Notation
```sql
SELECT $1, $2, $3, $4, $5
FROM @MY_STAGE 
(FILE_FORMAT => MY_FORMAT)
LIMIT 100;
```

## 🔍 Discover Data Structure First

```sql
-- Always run this FIRST
SELECT * FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@MY_STAGE',
    FILE_FORMAT => 'MY_FORMAT'
  )
);
```

**Returns**: Column count, names, and types

## 🐍 Python: Dynamic Column Selection

```python
# Get column count
schema = session.sql(f"""
    SELECT * FROM TABLE(
      INFER_SCHEMA(
        LOCATION => '@{stage_name}',
        FILE_FORMAT => '{format_name}'
      )
    )
""").collect()

num_columns = len(schema)

# Build positional SELECT
columns = ", ".join([f"${i+1}" for i in range(num_columns)])

# Query with dynamic columns
query = f"""
    SELECT {columns}
    FROM @{stage_name}
    (FILE_FORMAT => {format_name})
    LIMIT 100
"""
result = session.sql(query).collect()
```

## 📊 Three Data Access Methods

### Method 1: External Table (Can Fail)
```sql
-- May return empty if file paths have issues
SELECT * FROM MY_EXTERNAL_TABLE LIMIT 100;
```
**Pros**: SQL-friendly, reusable  
**Cons**: File path sensitivity, silent failures

### Method 2: Direct Stage Query (Reliable)
```sql
-- Always works if files exist
SELECT $1, $2, $3
FROM @MY_STAGE
(FILE_FORMAT => MY_FORMAT)
LIMIT 100;
```
**Pros**: Direct access, bypasses table issues  
**Cons**: Must use positional notation, no SELECT *

### Method 3: Staging Table (Most Reliable)
```sql
-- Copy to regular table
CREATE OR REPLACE TABLE STAGING_TABLE AS
SELECT $1 as col1, $2 as col2, $3 as col3
FROM @MY_STAGE
(FILE_FORMAT => MY_FORMAT);

-- Now you can use SELECT *
SELECT * FROM STAGING_TABLE LIMIT 100;
```
**Pros**: Fastest, SELECT * works, no issues  
**Cons**: Requires storage, data duplication

## 📋 CSV File Format Template

```sql
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1              -- ⚠️ CRITICAL for CSV with headers
  FIELD_DELIMITER = ','
  ESCAPE = NONE
  PARSE_HEADER = false         -- true if you want column names
  MULTI_LINE = true;           -- for multi-line values
```

## 🐛 Debugging Checklist

1. ✅ **Check stage has files**
   ```sql
   LIST @MY_STAGE;
   ```

2. ✅ **Verify file format**
   ```sql
   DESC FILE FORMAT MY_FORMAT;
   ```

3. ✅ **Infer schema**
   ```sql
   SELECT * FROM TABLE(INFER_SCHEMA(...));
   ```

4. ✅ **Test stage query**
   ```sql
   SELECT $1, $2, $3 FROM @MY_STAGE (...) LIMIT 10;
   ```

5. ✅ **Check external table**
   ```sql
   SELECT * FROM MY_EXTERNAL_TABLE LIMIT 10;
   ```

6. ✅ **Create staging table if needed**
   ```sql
   CREATE TABLE STAGING AS SELECT $1, $2 FROM @MY_STAGE (...);
   ```

## 🎨 Streamlit Session Pattern

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Always use try/except for compatibility
try:
    session = get_active_session()  # Works in SPCS/SiS
except:
    import os
    from snowflake.connector import connect
    conn = connect(
        connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "default"
    )
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

# ALWAYS set context
session.sql("USE DATABASE MY_DB").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("USE WAREHOUSE MY_WH").collect()
```

## 🎯 Streamlit Multi-Page Apps

### File Structure
```
streamlit_app.py         # Home page
pages/
  Data_Preview.py        # Auto-routes to /Data_Preview
  Pipeline_Tracker.py    # Auto-routes to /Pipeline_Tracker
```

### Page Naming Rules
- Filename: `Data_Preview.py`
- URL: `/Data_Preview`
- Title: "Data Preview" (underscores → spaces)

### Custom Title
```python
st.set_page_config(page_title="My Custom Title")
```

## 🔧 Common Errors and Fixes

### Error: "SELECT with no columns"
**Cause**: Using SELECT * on stage  
**Fix**: Use $1, $2, $3... notation

### Error: External table returns empty
**Cause**: File path issues or LOCATION mismatch  
**Fix**: Create staging table or query stage directly

### Error: Missing column headers
**Cause**: SKIP_HEADER not set  
**Fix**: Add SKIP_HEADER = 1 to file format

### Error: Data misaligned
**Cause**: Wrong FIELD_DELIMITER  
**Fix**: Match delimiter to actual file (comma, pipe, tab)

## 💡 Best Practices Summary

1. **Always use INFER_SCHEMA** before querying unknown data
2. **Never use SELECT *** on stages (use $1, $2, $3...)
3. **Provide multiple query options** in UI (external table + stage + staging)
4. **Set SKIP_HEADER = 1** for CSV files with headers
5. **Create staging tables** when file paths have issues
6. **Test in browser** after code changes
7. **Show clear error messages** with alternative suggestions
8. **Set database/schema/warehouse** context on every page

## 📖 When to Use Each Method

| Scenario | Use This Method |
|----------|----------------|
| Ad-hoc exploration | Direct stage query ($1, $2...) |
| Production queries | Staging table (best performance) |
| SQL-only access | External table (if paths are simple) |
| Unknown data structure | INFER_SCHEMA first |
| Files with spaces in path | Staging table (avoid external table) |
| Need SELECT * | Staging table (only option) |
| Minimal storage | Direct stage query |
| Maximum reliability | Staging table |

## 🚀 Quick Start Template

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

# Session
try:
    session = get_active_session()
except:
    import os
    from snowflake.connector import connect
    conn = connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME"))
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

# Context
session.sql("USE DATABASE MY_DB").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("USE WAREHOUSE MY_WH").collect()

st.title("My Data App")

# Query with error handling
try:
    # Method 1: Get column count
    schema = session.sql("""
        SELECT * FROM TABLE(
          INFER_SCHEMA(
            LOCATION => '@MY_STAGE',
            FILE_FORMAT => 'MY_FORMAT'
          )
        )
    """).collect()
    
    num_cols = len(schema)
    cols = ", ".join([f"${i+1}" for i in range(num_cols)])
    
    # Method 2: Query stage
    result = session.sql(f"""
        SELECT {cols}
        FROM @MY_STAGE
        (FILE_FORMAT => MY_FORMAT)
        LIMIT 100
    """).collect()
    
    # Method 3: Display
    if result:
        st.success(f"Found {len(result)} rows")
        st.dataframe(result, use_container_width=True)
    else:
        st.warning("No data found")
        
except Exception as e:
    st.error(f"Error: {str(e)}")
    st.info("💡 Try creating a staging table")
```

## 📚 Reference Files

- **Complete Guide**: `/Users/leyu/DATA_ENGINEER_AGENT/SKILL.md`
- **Update Summary**: `/Users/leyu/DATA_ENGINEER_AGENT/SKILL_UPDATE_SUMMARY.md`
- **Working Example**: `/Users/leyu/DATA_ENGINEER_AGENT/pages/Data_Preview.py`

---

**Last Updated**: February 1, 2026  
**Based On**: Production debugging experience with real Snowflake data pipelines
