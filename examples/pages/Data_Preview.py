import streamlit as st
import snowflake.snowpark as snowpark
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Data Preview", page_icon="📊", layout="wide")

st.title("📊 Data Preview")
st.markdown("Preview data from your external tables and stages")

try:
    session = get_active_session()
except:
    import os
    from snowflake import connector
    conn = connector.connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "pm")
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

session.sql("USE DATABASE LEILA_APP").collect()
session.sql("USE SCHEMA PUBLIC").collect()
session.sql("USE WAREHOUSE LEILAAPP").collect()

try:
    pipelines = session.sql("""
        SELECT 
            PIPELINE_ID,
            DATA_SOURCE_TYPE,
            TABLE_NAME,
            STAGE_NAME,
            FILE_FORMAT_NAME,
            STATUS,
            CREATED_AT
        FROM LEILA_APP.PUBLIC.DATA_PIPELINE_TRACKER
        ORDER BY CREATED_AT DESC
    """).collect()
    
    if pipelines:
        st.subheader("Select a Pipeline")
        
        pipeline_options = {f"{p['PIPELINE_ID']} ({p['DATA_SOURCE_TYPE']})": p for p in pipelines}
        selected = st.selectbox("Choose a pipeline to preview", options=list(pipeline_options.keys()))
        
        if selected:
            pipeline = pipeline_options[selected]
            
            col1, col2 = st.columns(2)
            with col1:
                st.metric("Status", pipeline['STATUS'])
                st.metric("Table", pipeline['TABLE_NAME'])
            with col2:
                st.metric("Data Source", pipeline['DATA_SOURCE_TYPE'])
                st.metric("Created", str(pipeline['CREATED_AT']))
            
            st.markdown("---")
            
            tab1, tab2 = st.tabs(["External Table", "Stage Data"])
            
            with tab1:
                st.subheader(f"📋 External Table: {pipeline['TABLE_NAME']}")
                
                limit = st.slider("Number of rows", min_value=10, max_value=1000, value=100, step=10)
                
                if st.button("🔍 Query Table", key="query_table"):
                    with st.spinner("Querying external table..."):
                        try:
                            result = session.sql(f"""
                                SELECT * FROM LEILA_APP.PUBLIC.{pipeline['TABLE_NAME']}
                                LIMIT {limit}
                            """).collect()
                            
                            if result:
                                st.success(f"Found {len(result)} rows")
                                st.dataframe(result, use_container_width=True)
                            else:
                                st.warning("No data returned from external table")
                                st.info("💡 Tip: Try querying the stage directly if the external table returns no data")
                        except Exception as e:
                            st.error(f"Error querying table: {str(e)}")
                            st.info("💡 Tip: Try the Stage Data tab to query directly from the stage")
            
            with tab2:
                st.subheader(f"📁 Stage: {pipeline['STAGE_NAME']}")
                
                if st.button("📂 List Files", key="list_files"):
                    with st.spinner("Listing files in stage..."):
                        try:
                            files = session.sql(f"""
                                LIST @LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}
                            """).collect()
                            
                            if files:
                                st.success(f"Found {len(files)} files")
                                st.dataframe(files, use_container_width=True)
                            else:
                                st.warning("No files found in stage")
                        except Exception as e:
                            st.error(f"Error listing files: {str(e)}")
                
                st.markdown("---")
                
                limit_stage = st.slider("Number of rows from stage", min_value=10, max_value=1000, value=100, step=10)
                
                if st.button("🔍 Query Stage Directly", key="query_stage"):
                    with st.spinner("Querying stage..."):
                        try:
                            result = session.sql(f"""
                                SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                                       $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
                                       $21, $22, $23
                                FROM @LEILA_APP.PUBLIC.{pipeline['STAGE_NAME']}
                                (FILE_FORMAT => LEILA_APP.PUBLIC.{pipeline['FILE_FORMAT_NAME']})
                                LIMIT {limit_stage}
                            """).collect()
                            
                            if result:
                                st.success(f"Found {len(result)} rows")
                                st.dataframe(result, use_container_width=True)
                                
                                st.markdown("### 📊 Column Info")
                                if len(result) > 0:
                                    st.write(f"Total columns: {len(result[0].asDict().keys())}")
                                    st.write("Column names:", list(result[0].asDict().keys()))
                            else:
                                st.warning("No data returned from stage")
                        except Exception as e:
                            st.error(f"Error querying stage: {str(e)}")
    else:
        st.info("No pipelines found. Create a pipeline first from the main page.")
        if st.button("🏠 Go to Main Page"):
            st.switch_page("Home.py")
            
except Exception as e:
    st.error(f"Error loading pipelines: {str(e)}")

st.sidebar.title("ℹ️ Data Preview")
st.sidebar.markdown("""
This page allows you to:

- 📊 View data from external tables
- 📁 List files in stages
- 🔍 Query stage data directly
- 📈 Preview pipeline data

**Two query methods:**
1. **External Table**: Structured table view
2. **Stage Data**: Raw data from files
""")
