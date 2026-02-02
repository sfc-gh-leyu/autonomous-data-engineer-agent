import streamlit as st
import snowflake.snowpark as snowpark
from snowflake.snowpark.context import get_active_session
import json
import uuid
from datetime import datetime

st.set_page_config(page_title="Data Engineer Agent", page_icon="🔧", layout="wide")

st.title("🔧 Autonomous Data Engineer Agent")
st.markdown("Describe your data source, and I'll generate the DDL and set up your pipeline automatically.")

try:
    session = get_active_session()
except:
    import os
    from snowflake import connector
    conn = connector.connect(connection_name=os.getenv("SNOWFLAKE_CONNECTION_NAME") or "pm")
    from snowflake.snowpark import Session
    session = Session.builder.configs({"connection": conn}).create()

if "messages" not in st.session_state:
    st.session_state.messages = []
if "thread_id" not in st.session_state:
    st.session_state.thread_id = None
if "pipeline_config" not in st.session_state:
    st.session_state.pipeline_config = {}

def call_agent(message: str, thread_id: str = None):
    if not thread_id:
        thread_result = session.sql("SELECT SYSTEM$CREATE_CORTEX_THREAD('data_engineer_app')").collect()
        thread_id = thread_result[0][0]
        st.session_state.thread_id = thread_id
    
    sql = f"""
    SELECT SYSTEM$RUN_CORTEX_AGENT(
        '<DATABASE>.PUBLIC.<AGENT_NAME>',
        '{thread_id}',
        PARSE_JSON('{json.dumps({"messages": [{"role": "user", "content": message}]})}')
    )
    """
    
    result = session.sql(sql).collect()
    return json.loads(result[0][0])

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
                FROM <DATABASE>.PUBLIC.DATA_PIPELINE_TRACKER
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
st.sidebar.caption(f"Agent: <DATABASE>.PUBLIC.<AGENT_NAME>")
