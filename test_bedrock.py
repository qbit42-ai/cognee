#!/usr/bin/env python3
"""
Test script for AWS Bedrock connection using litellm.
Can be run directly or called from test-bedrock.sh
"""

import os
import sys
import litellm
from litellm import completion, embedding

# Suppress verbose logging
litellm.set_verbose = False
os.environ.setdefault("LITELLM_LOG", "ERROR")

def test_bedrock(
    model: str = None,
    endpoint: str = None,
    api_key: str = None,
    test_message: str = "Say 'Hello, Bedrock!' if you can hear me."
):
    """
    Test Bedrock connection with litellm.
    
    Args:
        model: Model name (e.g., "bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0")
        endpoint: API endpoint URL (optional)
        api_key: API key (optional, Bedrock doesn't use it but litellm may validate it)
        test_message: Test message to send
    """
    # Get configuration from environment or parameters
    model = model or os.getenv("LLM_MODEL", "bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0")
    endpoint = endpoint if endpoint is not None else os.getenv("LLM_ENDPOINT", "")
    api_key = api_key if api_key is not None else os.getenv("LLM_API_KEY", "")
    
    print(f"🔍 Testing with configuration:")
    print(f"   Model: {model}")
    print(f"   Endpoint: {endpoint if endpoint else '(not set)'}")
    print(f"   API Key: {'(set)' if api_key else '(not set)'}")
    print(f"   AWS Region: {os.getenv('AWS_REGION', os.getenv('AWS_REGION_NAME', 'not set'))}")
    print(f"   AWS Access Key ID: {os.getenv('AWS_ACCESS_KEY_ID', 'not set')[:20]}...")
    print("")

    # Build kwargs for litellm
    kwargs = {
        "model": model,
        "messages": [
            {"role": "user", "content": test_message}
        ],
    }

    # Conditionally add endpoint and api_key
    # Note: For Bedrock, ideally we shouldn't pass api_key, but cognee adapter always does
    if endpoint:
        kwargs["api_base"] = endpoint

    if api_key:
        kwargs["api_key"] = api_key

    print("🚀 Calling litellm.completion...")
    print("")

    try:
        response = completion(**kwargs)
        
        print("✅ SUCCESS!")
        print("")
        print("📝 Response:")
        if hasattr(response, 'choices') and len(response.choices) > 0:
            content = response.choices[0].message.content
            print(content)
        else:
            print(response)
        print("")
        return True
        
    except Exception as e:
        print("❌ ERROR:")
        print(f"   {type(e).__name__}: {str(e)}")
        print("")
        
        # Print more details if available
        if hasattr(e, 'message'):
            print(f"   Message: {e.message}")
        if hasattr(e, 'status_code'):
            print(f"   Status Code: {e.status_code}")
        
        import traceback
        print("\n📚 Full traceback:")
        traceback.print_exc()
        return False


def test_bedrock_embedding(
    model: str = None,
    endpoint: str = None,
    api_key: str = None,
    test_text: str = "This is a test sentence for embedding."
):
    """
    Test Bedrock embedding connection with litellm.
    
    Args:
        model: Embedding model name (e.g., "bedrock/eu.amazon.titan-embed-text-v1")
        endpoint: API endpoint URL (optional)
        api_key: API key (optional, Bedrock doesn't use it but litellm may validate it)
        test_text: Test text to embed
    """
    # Get configuration from environment or parameters
    # Note: Bedrock embeddings may not support region prefix in model name
    # Try without region prefix first (bedrock/amazon.titan-embed-text-v1)
    default_model = os.getenv("EMBEDDING_MODEL", "bedrock/amazon.titan-embed-text-v1")
    # Remove region prefix if present (eu.amazon -> amazon)
    if default_model.startswith("bedrock/") and "." in default_model.split("/", 1)[1]:
        parts = default_model.split("/", 1)[1].split(".", 1)
        if len(parts) == 2 and parts[0] in ["eu", "us", "ap"]:
            # Remove region prefix
            default_model = f"bedrock/{parts[1]}"
    
    model = model or default_model
    endpoint = endpoint if endpoint is not None else os.getenv("EMBEDDING_ENDPOINT", os.getenv("LLM_ENDPOINT", ""))
    api_key = api_key if api_key is not None else os.getenv("EMBEDDING_API_KEY", os.getenv("LLM_API_KEY", ""))
    
    print(f"🔍 Testing embeddings with configuration:")
    print(f"   Model: {model}")
    print(f"   Endpoint: {endpoint if endpoint else '(not set)'}")
    print(f"   API Key: {'(set)' if api_key else '(not set)'}")
    print(f"   AWS Region: {os.getenv('AWS_REGION', os.getenv('AWS_REGION_NAME', 'not set'))}")
    print(f"   AWS Access Key ID: {os.getenv('AWS_ACCESS_KEY_ID', 'not set')[:20]}...")
    print("")

    # Build kwargs for litellm
    # For Bedrock embeddings, try without endpoint first (let litellm use AWS SDK directly)
    aws_region = os.getenv("AWS_REGION", os.getenv("AWS_REGION_NAME", ""))
    
    kwargs = {
        "model": model,
        "input": [test_text],
    }
    
    # Pass AWS region explicitly for Bedrock
    if aws_region:
        kwargs["aws_region_name"] = aws_region

    # Don't pass api_key for Bedrock - it uses AWS credentials from environment
    # if api_key:
    #     kwargs["api_key"] = api_key

    print("🚀 Calling litellm.embedding...")
    print("   (Trying without endpoint first - litellm will use AWS SDK)")
    print("")

    try:
        # First try without endpoint
        response = embedding(**kwargs)
        
        print("✅ SUCCESS!")
        print("")
        print("📝 Response:")
        if hasattr(response, 'data') and len(response.data) > 0:
            embedding_vector = response.data[0].embedding
            print(f"   Embedding dimension: {len(embedding_vector)}")
            print(f"   First 5 values: {embedding_vector[:5]}")
            print(f"   Last 5 values: {embedding_vector[-5:]}")
        else:
            print(response)
        print("")
        return True
        
    except Exception as e:
        print("❌ ERROR:")
        print(f"   {type(e).__name__}: {str(e)}")
        print("")
        
        # Print more details if available
        if hasattr(e, 'message'):
            print(f"   Message: {e.message}")
        if hasattr(e, 'status_code'):
            print(f"   Status Code: {e.status_code}")
        
        import traceback
        print("\n📚 Full traceback:")
        traceback.print_exc()
        # If that fails and endpoint is set, try with endpoint
        if endpoint and "Unable to map Bedrock request" in str(e):
            print("   Retrying with endpoint...")
            print("")
            try:
                kwargs_with_endpoint = kwargs.copy()
                kwargs_with_endpoint["api_base"] = endpoint
                response = embedding(**kwargs_with_endpoint)
                
                print("✅ SUCCESS (with endpoint)!")
                print("")
                print("📝 Response:")
                if hasattr(response, 'data') and len(response.data) > 0:
                    embedding_vector = response.data[0].embedding
                    print(f"   Embedding dimension: {len(embedding_vector)}")
                    print(f"   First 5 values: {embedding_vector[:5]}")
                    print(f"   Last 5 values: {embedding_vector[-5:]}")
                else:
                    print(response)
                print("")
                return True
            except Exception as e2:
                print("❌ ERROR (with endpoint):")
                print(f"   {type(e2).__name__}: {str(e2)}")
                print("")
        
        return False


if __name__ == "__main__":
    # Allow command-line arguments to override environment variables
    import argparse
    
    parser = argparse.ArgumentParser(description="Test AWS Bedrock connection with litellm")
    parser.add_argument("--model", help="Model name (e.g., bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0)")
    parser.add_argument("--endpoint", help="API endpoint URL")
    parser.add_argument("--api-key", help="API key (Bedrock doesn't use it, but may be validated)")
    parser.add_argument("--message", default="Say 'Hello, Bedrock!' if you can hear me.", help="Test message")
    parser.add_argument("--no-endpoint", action="store_true", help="Don't pass endpoint (unset it)")
    parser.add_argument("--no-api-key", action="store_true", help="Don't pass API key (unset it)")
    parser.add_argument("--test-embedding", action="store_true", help="Test embeddings instead of completion")
    parser.add_argument("--test-text", help="Text to embed (for embedding test)")
    
    args = parser.parse_args()
    
    endpoint = None if args.no_endpoint else (args.endpoint if args.endpoint is not None else None)
    api_key = None if args.no_api_key else (args.api_key if args.api_key is not None else None)
    
    if args.test_embedding:
        success = test_bedrock_embedding(
            model=args.model,
            endpoint=endpoint,
            api_key=api_key,
            test_text=args.test_text or "This is a test sentence for embedding."
        )
    else:
        success = test_bedrock(
            model=args.model,
            endpoint=endpoint,
            api_key=api_key,
            test_message=args.message
        )
    
    sys.exit(0 if success else 1)
