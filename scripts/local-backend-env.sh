#!/usr/bin/env bash
# Helper script to run local backends with proper environment variables

cat << 'EOF'
🔧 Local Backend Development Environment Variables
==================================================

Add these environment variables when running your backends locally:

For Provider Backend (port 3001):
export NODE_TLS_REJECT_UNAUTHORIZED=0
export CLIENT_BASE_URL=https://client.localhost/api/
export DATABASE_URL=postgresql://app:StrongLocalPass@localhost:5433/db

For Client Backend (port 3000):  
export NODE_TLS_REJECT_UNAUTHORIZED=0
export DATABASE_URL=postgresql://app:StrongLocalPass@localhost:5432/db

Example usage:
cd /path/to/your/backend
NODE_TLS_REJECT_UNAUTHORIZED=0 npm run start:dev

Or create a .env.local file with:
NODE_TLS_REJECT_UNAUTHORIZED=0
DATABASE_URL=postgresql://app:StrongLocalPass@localhost:5432/db

EOF