#!/bin/bash
# Script to test AWS Bedrock connection using litellm
# Allows easy testing with different configurations

set -e

echo "🧪 Testing AWS Bedrock connection with litellm..."
echo ""

# Default configuration
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-AKIAR4OCYWEXTSQODAQF}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-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}"
export AWS_REGION="${AWS_REGION:-${AWS_REGION_NAME:-eu-central-1}}"
export AWS_REGION_NAME="${AWS_REGION_NAME:-$AWS_REGION}"

# Model configuration
export LLM_MODEL="${LLM_MODEL:-bedrock/eu.anthropic.claude-3-7-sonnet-20250219-v1:0}"

# Endpoint configuration - try different options
# Option 1: Set to proper Bedrock endpoint URL
export LLM_ENDPOINT="${LLM_ENDPOINT:-https://bedrock-runtime.${AWS_REGION}.amazonaws.com}"

# Option 2: Uncomment to test without endpoint (may cause InvalidURL)
# unset LLM_ENDPOINT

# Option 3: Uncomment to test with empty endpoint
# export LLM_ENDPOINT=""

# API Key configuration - try different options
# Option 1: Empty string (may cause validation errors)
export LLM_API_KEY="${LLM_API_KEY:-}"

# Option 2: Uncomment to use AWS_ACCESS_KEY_ID as "API key"
# export LLM_API_KEY="${LLM_API_KEY:-${AWS_ACCESS_KEY_ID}}"

# Option 3: Uncomment to use a dummy value
# export LLM_API_KEY="${LLM_API_KEY:-dummy-bedrock-key}"

# Embedding configuration (for testing embeddings)
# Note: Bedrock embeddings may not support region prefix in model name
# Try without region prefix first (bedrock/amazon.titan-embed-text-v1)
export EMBEDDING_MODEL="${EMBEDDING_MODEL:-bedrock/amazon.titan-embed-text-v1}"
export EMBEDDING_ENDPOINT="${EMBEDDING_ENDPOINT:-${LLM_ENDPOINT}}"
export EMBEDDING_API_KEY="${EMBEDDING_API_KEY:-${LLM_API_KEY}}"

echo "📋 Configuration:"
echo "   LLM Model: $LLM_MODEL"
echo "   Embedding Model: $EMBEDDING_MODEL"
echo "   AWS Region: $AWS_REGION"
echo "   AWS Access Key: ${AWS_ACCESS_KEY_ID:0:20}..."
echo "   Endpoint: ${LLM_ENDPOINT:-'(not set)'}"
echo "   API Key: ${LLM_API_KEY:-(not set)}"
echo ""

# Check if Python 3.12 is available
if ! command -v python3.12 &> /dev/null; then
    echo "❌ Python 3.12 is required but not found!"
    echo "   Using python3 instead..."
    PYTHON_CMD="python3"
else
    PYTHON_CMD="python3.12"
fi

echo "✅ Using Python: $($PYTHON_CMD --version)"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test_bedrock.py"

# Check if test script exists
if [ ! -f "$TEST_SCRIPT" ]; then
    echo "❌ Test script not found: $TEST_SCRIPT"
    echo "   Please ensure test_bedrock.py is in the same directory as this script."
    exit 1
fi

# Run the test script
echo "🧪 Running LLM completion test..."
echo ""

if command -v uv &> /dev/null; then
    # Use uv if available (matches cognee setup)
    UV_PYTHON=$PYTHON_CMD uv run python "$TEST_SCRIPT"
else
    # Fallback to direct Python
    $PYTHON_CMD "$TEST_SCRIPT"
fi

LLM_SUCCESS=$?

echo ""
echo "🧪 Running embedding test..."
echo ""

if command -v uv &> /dev/null; then
    UV_PYTHON=$PYTHON_CMD uv run python "$TEST_SCRIPT" --test-embedding
else
    $PYTHON_CMD "$TEST_SCRIPT" --test-embedding
fi

EMBEDDING_SUCCESS=$?

echo ""
if [ $LLM_SUCCESS -eq 0 ] && [ $EMBEDDING_SUCCESS -eq 0 ]; then
    echo "✨ All tests completed successfully!"
    exit 0
else
    echo "⚠️  Some tests failed:"
    [ $LLM_SUCCESS -ne 0 ] && echo "   ❌ LLM completion test failed"
    [ $EMBEDDING_SUCCESS -ne 0 ] && echo "   ❌ Embedding test failed"
    exit 1
fi
