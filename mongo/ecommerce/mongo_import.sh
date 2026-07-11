#!/bin/bash

# Import the ecommerce sample database into MongoDB.
# Document model: addresses are embedded in users; variants, images and
# stock in products; items, status history, payment and shipment in orders.
# Dates use extended-JSON {"$date": ...} so they import as real Date values.
#
# Run from this directory against a local MongoDB:
#   sh mongo_import.sh
# Or point at another server:
#   MONGO_URI="mongodb://host:27017" sh mongo_import.sh

URI="${MONGO_URI:-mongodb://localhost:27017}"

for c in users categories products carriers orders carts; do
    mongoimport --uri "$URI" -d ecommerce -c "$c" --drop --jsonArray --file "$c.json"
done
