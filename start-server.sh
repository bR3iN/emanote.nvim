#!/usr/bin/bash
set -e
if ! [ -d venv ]; then
    python3 -m venv venv
fi
source venv/bin/activate
INITIAL_SITE="$2" uvicorn fastapi-server:app --port "$1"
