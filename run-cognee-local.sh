#!/bin/bash

set -e

echo "🚀 Starting Cognee locally..."

if ! command -v python3.12 &> /dev/null; then
    echo "❌ Python 3.12 is required but not found!"
    echo ""
    echo "📦 Install Python 3.12 using Homebrew:"
    echo "   brew install python@3.12"
    echo ""
    echo "Or use pyenv:"
    echo "   pyenv install 3.12.7"
    echo "   pyenv local 3.12.7"
    exit 1
fi

echo "✅ Found Python 3.12: $(python3.12 --version)"

export PYTHON_VERSION="3.12"
export LLM_PROVIDER="${LLM_PROVIDER:-openai}"
export HTTP_PORT="${HTTP_PORT:-8001}"
export HOST="${HOST:-0.0.0.0}"
export ENVIRONMENT="${ENVIRONMENT:-local}"
export LOG_LEVEL="${LOG_LEVEL:-ERROR}"
export DEBUG="${DEBUG:-false}"
export PYTHONUNBUFFERED=1
export TELEMETRY_DISABLED="${TELEMETRY_DISABLED:-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-AKIAR4OCYWEXTSQODAQF}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-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}"
export AWS_REGION="${AWS_REGION:-${AWS_REGION_NAME:-eu-central-1}}"
export AWS_REGION_NAME="${AWS_REGION_NAME:-$AWS_REGION}"

export LLM_MODEL="${LLM_MODEL:-bedrock/eu.anthropic.claude-3-7-sonnet-20250219-v1:0}"
export LLM_ENDPOINT="${LLM_ENDPOINT:-https://bedrock-runtime.${AWS_REGION}.amazonaws.com}"
export LLM_API_KEY="${LLM_API_KEY:-}"

export EMBEDDING_API_KEY="${EMBEDDING_API_KEY:-${LLM_API_KEY}}"
export EMBEDDING_PROVIDER="openai"
export EMBEDDING_MODEL="${EMBEDDING_MODEL:-bedrock/amazon.titan-embed-text-v1}"
export EMBEDDING_DIMENSIONS="${EMBEDDING_DIMENSIONS:-1536}"

export DB_PROVIDER="${DB_PROVIDER:-sqlite}"
export VECTOR_DB_PROVIDER="${VECTOR_DB_PROVIDER:-lancedb}"
export GRAPH_DATABASE_PROVIDER="${GRAPH_DATABASE_PROVIDER:-kuzu}"


if [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ "$AWS_SECRET_ACCESS_KEY" = "YOUR_AWS_SECRET" ]; then
    echo ""
    echo "⚠️  WARNING: AWS_SECRET_ACCESS_KEY is not set!"
    echo ""
    echo "Please set your AWS Bedrock credentials:"
    echo "   export AWS_ACCESS_KEY_ID='AKIA...'"
    echo "   export AWS_SECRET_ACCESS_KEY='your-secret-key'"
    echo "   export AWS_REGION='eu-central-1'"
    echo ""
    echo "Or edit this script and replace 'YOUR_AWS_SECRET'"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo ""
echo "📝 Writing environment variables to .env file..."
cat > "$ENV_FILE" << EOF
PYTHON_VERSION=$PYTHON_VERSION
LLM_PROVIDER=$LLM_PROVIDER
HTTP_PORT=$HTTP_PORT
HOST=$HOST
ENVIRONMENT=$ENVIRONMENT
LOG_LEVEL=$LOG_LEVEL
DEBUG=$DEBUG
PYTHONUNBUFFERED=$PYTHONUNBUFFERED
TELEMETRY_DISABLED=$TELEMETRY_DISABLED
EMBEDDING_DIMENSIONS=$EMBEDDING_DIMENSIONS
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_REGION=$AWS_REGION
AWS_REGION_NAME=$AWS_REGION_NAME
LLM_MODEL=$LLM_MODEL
LLM_ENDPOINT=$LLM_ENDPOINT
LLM_API_KEY=$LLM_API_KEY
EMBEDDING_API_KEY=$EMBEDDING_API_KEY
EMBEDDING_PROVIDER=$EMBEDDING_PROVIDER
EMBEDDING_MODEL=$EMBEDDING_MODEL
DB_PROVIDER=$DB_PROVIDER
VECTOR_DB_PROVIDER=$VECTOR_DB_PROVIDER
GRAPH_DATABASE_PROVIDER=$GRAPH_DATABASE_PROVIDER
EOF

echo "✅ .env file updated: $ENV_FILE"
echo ""

echo "📋 Configuration:"
echo "   Python: $(python3.12 --version)"
echo "   LLM Provider: $LLM_PROVIDER (using AWS Bedrock via litellm)"
echo "   LLM Model: $LLM_MODEL"
echo "   Embedding Model: $EMBEDDING_MODEL"
echo "   AWS Region: $AWS_REGION"
echo "   Host: $HOST"
echo "   Port: $HTTP_PORT"
echo ""

echo "📦 Installing dependencies with uv (Python 3.12)..."
UV_PYTHON=python3.12 uv sync --dev --all-extras --reinstall

echo ""
echo "🔄 Running database migrations..."
UV_PYTHON=python3.12 uv run alembic upgrade head

echo ""
echo "🌐 Starting Cognee API server on http://$HOST:$HTTP_PORT"
echo "   📚 API Docs: http://localhost:$HTTP_PORT/docs"
echo ""
echo "Press Ctrl+C to stop"
echo ""

UV_PYTHON=python3.12 uv run gunicorn \
    -w 1 \
    -k uvicorn.workers.UvicornWorker \
    -t 30000 \
    --bind=0.0.0.0:$HTTP_PORT \
    --log-level debug \
    --reload \
    cognee.api.client:app
