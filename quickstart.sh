#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Autonomous Data Engineer Agent - Quick Start Guide          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "📦 What you have:"
echo "  ✓ Cortex Agent (<DATABASE>.PUBLIC.<AGENT_NAME>)"
echo "  ✓ 5 Custom Tools (Stored Procedures)"
echo "  ✓ Pipeline Tracker Table"
echo "  ✓ Streamlit Dashboard Application"
echo "  ✓ SPCS Deployment Files"
echo ""

PS3="Select an option: "
options=(
    "🚀 Deploy to SPCS (Full Deployment)"
    "💻 Run Streamlit Locally (Development)"
    "🧪 Test Agent via SQL (Quick Test)"
    "📊 View Pipeline History"
    "ℹ️  Show Documentation"
    "❌ Exit"
)

select opt in "${options[@]}"
do
    case $opt in
        "🚀 Deploy to SPCS (Full Deployment)")
            echo ""
            echo "Starting SPCS deployment..."
            echo "This will:"
            echo "  1. Create image repository"
            echo "  2. Build Docker image"
            echo "  3. Push to Snowflake registry"
            echo "  4. Create compute pool"
            echo "  5. Deploy service"
            echo ""
            read -p "Continue? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                ./deploy.sh
            fi
            break
            ;;
        "💻 Run Streamlit Locally (Development)")
            echo ""
            echo "Starting Streamlit locally..."
            echo ""
            echo "Installing dependencies..."
            pip install -q streamlit snowflake-snowpark-python snowflake-connector-python
            echo ""
            echo "Launching Streamlit on http://localhost:8501"
            echo "Press Ctrl+C to stop"
            echo ""
            SNOWFLAKE_CONNECTION_NAME=pm streamlit run streamlit_app.py
            break
            ;;
        "🧪 Test Agent via SQL (Quick Test)")
            echo ""
            echo "Testing agent with SQL..."
            echo ""
            echo "Step 1: Creating conversation thread..."
            THREAD_ID=$(snow sql -q "SELECT SYSTEM\$CREATE_CORTEX_THREAD('quickstart_test');" -c <connection> --format json | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['SYSTEM\$CREATE_CORTEX_THREAD(\'QUICKSTART_TEST\')'])")
            echo "Thread ID: $THREAD_ID"
            echo ""
            echo "Step 2: Sending test message..."
            echo "Message: 'What can you help me with?'"
            echo ""
            snow sql -q "SELECT SYSTEM\$RUN_CORTEX_AGENT('<DATABASE>.PUBLIC.<AGENT_NAME>', '$THREAD_ID', PARSE_JSON('{\"messages\": [{\"role\": \"user\", \"content\": \"What can you help me with?\"}]}'));" -c <connection>
            echo ""
            echo "Test complete!"
            break
            ;;
        "📊 View Pipeline History")
            echo ""
            echo "Recent pipelines:"
            snow sql -q "SELECT PIPELINE_ID, DATA_SOURCE_TYPE, STATUS, CREATED_AT FROM <DATABASE>.PUBLIC.DATA_PIPELINE_TRACKER ORDER BY CREATED_AT DESC LIMIT 10;" -c <connection>
            break
            ;;
        "ℹ️  Show Documentation")
            echo ""
            echo "📚 Documentation Files:"
            echo ""
            echo "  📄 README.md              - Complete documentation"
            echo "  📄 DEPLOYMENT_SUMMARY.md  - Deployment overview"
            echo "  📄 ARCHITECTURE.md        - System architecture"
            echo ""
            echo "Quick Examples:"
            echo ""
            echo "Example 1: AWS S3 CSV Pipeline"
            echo "  'I have CSV files in s3://my-bucket/sales/ with columns:"
            echo "   order_id NUMBER, customer VARCHAR, amount DECIMAL, date DATE'"
            echo ""
            echo "Example 2: Azure Parquet Pipeline"
            echo "  'Set up a pipeline for Parquet files in"
            echo "   azure://account.blob.core.windows.net/logs/'"
            echo ""
            echo "Example 3: GCS JSON Pipeline"
            echo "  'I need to query JSON files from gs://my-bucket/events/'"
            echo ""
            read -p "Press Enter to continue..."
            break
            ;;
        "❌ Exit")
            echo "Goodbye!"
            break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "For more information, see:"
echo "  • README.md - Full documentation"
echo "  • DEPLOYMENT_SUMMARY.md - Quick reference"
echo "  • ARCHITECTURE.md - System design"
echo "═══════════════════════════════════════════════════════════════"
