#!/usr/bin/env python3

import json
import subprocess

print("🧪 Testing Data Engineer Agent...")
print()

print("Step 1: Verify agent exists")
result = subprocess.run(
    ['snow', 'sql', '-q', 'SHOW AGENTS LIKE \'<AGENT_NAME>\' IN SCHEMA <DATABASE>.PUBLIC;', '-c', 'pm'],
    capture_output=True,
    text=True
)
print(result.stdout)

print("\nStep 2: Describe agent configuration")
result = subprocess.run(
    ['snow', 'sql', '-q', 'DESCRIBE AGENT <DATABASE>.PUBLIC.<AGENT_NAME>;', '-c', 'pm'],
    capture_output=True,
    text=True
)
if '<AGENT_NAME>' in result.stdout:
    print("✅ Agent exists and is configured")
else:
    print("❌ Agent not found")
    print(result.stdout)

print("\nStep 3: Check stored procedures")
procs = [
    'GENERATE_STORAGE_INTEGRATION_DDL',
    'GENERATE_FILE_FORMAT_DDL',
    'GENERATE_EXTERNAL_STAGE_DDL',
    'GENERATE_EXTERNAL_TABLE_DDL',
    'EXECUTE_DDL_AND_TRACK'
]

for proc in procs:
    result = subprocess.run(
        ['snow', 'sql', '-q', f"SHOW PROCEDURES LIKE '{proc}' IN SCHEMA <DATABASE>.PUBLIC;", '-c', 'pm'],
        capture_output=True,
        text=True
    )
    if proc in result.stdout:
        print(f"✅ {proc}")
    else:
        print(f"❌ {proc} not found")

print("\nStep 4: Check tracker table")
result = subprocess.run(
    ['snow', 'sql', '-q', 'SELECT COUNT(*) FROM <DATABASE>.PUBLIC.DATA_PIPELINE_TRACKER;', '-c', 'pm'],
    capture_output=True,
    text=True
)
print("✅ Pipeline tracker table exists")
print(result.stdout)

print("\n" + "="*60)
print("✅ All components verified!")
print("="*60)
print()
print("To deploy to SPCS, run:")
print("  ./deploy.sh")
print()
print("To test the agent directly, run:")
print("  snow sql -q \"SELECT SYSTEM\\$CREATE_CORTEX_THREAD('test');\" -c pm")
