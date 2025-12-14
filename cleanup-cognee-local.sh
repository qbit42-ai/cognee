#!/bin/bash

set -e

echo "🧹 Starting cleanup of all Cognee test data..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COGNEE_DIR="$SCRIPT_DIR/cognee"

if [ ! -d "$COGNEE_DIR" ]; then
    echo "❌ cognee directory not found at $COGNEE_DIR"
    exit 1
fi

echo "🗑️  Cleaning up Cognee data directories..."

COGNEE_DIRS=(
    "$COGNEE_DIR/.cognee_system"
    "$COGNEE_DIR/.data_storage"
    "$COGNEE_DIR/.cognee_cache"
)

for dir in "${COGNEE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   Deleting: $dir"
        rm -rf "$dir"
        echo "   ✅ Deleted"
    else
        echo "   ℹ️  Not found (may already be deleted): $dir"
    fi
done

echo ""
echo "🗑️  Cleaning up MongoDB collections..."

KNOWLEDGESPACE_DIR="$(cd "$SCRIPT_DIR/../qbit-knowledgespace" 2>/dev/null && pwd)"

if [ ! -d "$KNOWLEDGESPACE_DIR" ]; then
    echo "⚠️  qbit-knowledgespace directory not found at $SCRIPT_DIR/../qbit-knowledgespace"
    echo "   Skipping MongoDB cleanup"
    exit 0
fi

if [ ! -f "$KNOWLEDGESPACE_DIR/server/lib/db/connectDb.js" ]; then
    echo "❌ MongoDB connection file not found"
    exit 1
fi

cd "$KNOWLEDGESPACE_DIR"

if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in qbit-knowledgespace"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found. Make sure MONGO_URI is set."
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed or not in PATH"
    echo "   Please install Node.js to clean up MongoDB collections"
    exit 1
fi

node << 'EOF'
require('dotenv').config();
const mongoose = require('mongoose');
const { Dataspace, DataspaceMember, Dataset, DatasetMapping, CogneeUser } = require('./server/models');

let MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
    console.error('❌ MONGO_URI environment variable is not set');
    console.error('   Please set MONGO_URI in your .env file or environment');
    process.exit(1);
}

const dockerHostnames = ['qbit42_local_chat_mongodb'];
const isDockerHostname = dockerHostnames.some(hostname => MONGO_URI.includes(hostname));

if (isDockerHostname) {
    console.log('🔄 Detected Docker hostname in MONGO_URI, replacing with localhost...');
    const originalUri = MONGO_URI;
    MONGO_URI = MONGO_URI.replace(/qbit42_local_chat_mongodb/g, 'localhost');
    console.log(`   Original: ${originalUri}`);
    console.log(`   Using: ${MONGO_URI}`);
}

async function cleanup() {
    try {
        console.log('📡 Connecting to MongoDB...');
        await mongoose.connect(MONGO_URI);
        console.log('✅ Connected to MongoDB');

        console.log('');
        console.log('🗑️  Deleting collections...');

        const results = {
            CogneeUser: 0,
            DatasetMapping: 0,
            Dataset: 0,
            DataspaceMember: 0,
            Dataspace: 0,
        };

        const cogneeUserResult = await CogneeUser.deleteMany({});
        results.CogneeUser = cogneeUserResult.deletedCount;
        console.log(`   ✓ Deleted ${results.CogneeUser} CogneeUser documents`);

        const datasetMappingResult = await DatasetMapping.deleteMany({});
        results.DatasetMapping = datasetMappingResult.deletedCount;
        console.log(`   ✓ Deleted ${results.DatasetMapping} DatasetMapping documents`);

        const datasetResult = await Dataset.deleteMany({});
        results.Dataset = datasetResult.deletedCount;
        console.log(`   ✓ Deleted ${results.Dataset} Dataset documents`);

        const dataspaceMemberResult = await DataspaceMember.deleteMany({});
        results.DataspaceMember = dataspaceMemberResult.deletedCount;
        console.log(`   ✓ Deleted ${results.DataspaceMember} DataspaceMember documents`);

        const dataspaceResult = await Dataspace.deleteMany({});
        results.Dataspace = dataspaceResult.deletedCount;
        console.log(`   ✓ Deleted ${results.Dataspace} Dataspace documents`);

        console.log('');
        console.log('✅ MongoDB cleanup completed!');
        console.log('');
        console.log('📊 Summary:');
        console.log(`   Dataspaces: ${results.Dataspace}`);
        console.log(`   Dataspace Members: ${results.DataspaceMember}`);
        console.log(`   Datasets: ${results.Dataset}`);
        console.log(`   Dataset Mappings: ${results.DatasetMapping}`);
        console.log(`   Cognee Users: ${results.CogneeUser}`);

        await mongoose.connection.close();
        console.log('');
        console.log('✅ Disconnected from MongoDB');
    } catch (error) {
        console.error('❌ Error during cleanup:', error.message);
        if (mongoose.connection.readyState === 1) {
            await mongoose.connection.close();
        }
        process.exit(1);
    }
}

cleanup();
EOF

echo ""
echo "✅ All cleanup completed successfully!"
echo ""
echo "📋 Cleaned up:"
echo "   • Cognee system directory (.cognee_system)"
echo "   • Cognee data storage (.data_storage)"
echo "   • Cognee cache (.cognee_cache)"
echo "   • MongoDB collections (Dataspaces, Datasets, etc.)"
echo ""
echo "⚠️  Note: This script deletes ALL test data. Make sure you want to do this!"