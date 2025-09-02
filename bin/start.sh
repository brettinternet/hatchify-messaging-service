#!/bin/bash

set -e

echo "Starting the application..."

ENV=${ENVIRONMENT:-development}
echo "Environment: ${ENV}"
echo "Port: ${SERVER_PORT:-8080}"

mix run --no-halt &

echo "Application started successfully!"
