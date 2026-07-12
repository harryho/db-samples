#!/bin/bash

# Import the ecommerce sample database into MongoDB.
# Document model: addresses are embedded in users; variants, images and
# stock in products; items, status history, payment and shipment in orders.
# Dates use extended-JSON {"$date": ...} so they import as real Date values.
#
# Prefers a local mongoimport; falls back to the mongo-infra Docker
# container started by ../../renew-mongo-infra.sh (or .ps1).
#
# Run from this directory:
#   ./mongo_import.sh
# Or point a local mongoimport at another server:
#   MONGO_URI="mongodb://host:27017" ./mongo_import.sh

set -e  # Exit on error

URI="${MONGO_URI:-mongodb://localhost:27017}"
DATABASE="ecommerce"
COLLECTIONS="users categories products carriers orders carts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v mongoimport > /dev/null 2>&1; then
    echo "Using local mongoimport"
    for c in $COLLECTIONS; do
        mongoimport --uri "$URI" -d "$DATABASE" -c "$c" --drop --jsonArray --file "${SCRIPT_DIR}/${c}.json"
    done
elif docker ps --format '{{.Names}}' | grep -q "mongo-infra"; then
    echo "Using mongoimport from Docker container (mongo-infra)"
    for c in $COLLECTIONS; do
        docker cp "${SCRIPT_DIR}/${c}.json" "mongo-infra:/tmp/${c}.json"
        docker exec mongo-infra mongoimport -d "$DATABASE" -c "$c" --drop --jsonArray --file "/tmp/${c}.json"
        docker exec mongo-infra rm -f "/tmp/${c}.json"
    done
else
    echo "Error: mongoimport not found and Docker container 'mongo-infra' is not running"
    echo ""
    echo "Options:"
    echo "1. Install the MongoDB Database Tools (mongoimport)"
    echo "2. Run the Docker container: docker-compose up -d mongo (or ./renew-mongo-infra.sh)"
    exit 1
fi

echo ""
echo "✓ Imported '${DATABASE}' into MongoDB"
