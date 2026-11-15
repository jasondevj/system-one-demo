#!/bin/sh
# Capture REAL /api/decide responses from a healthy live ollaya into ./canned/.
# Run this before the talk (ollaya on localhost:11435) and commit the results -
# real captures are always better than the hand-written placeholders in this repo.
set -e
cd "$(dirname "$0")"
OLLAYA="${OLLAYA_URL:-http://localhost:11435}"

post () {
  curl -sS -X POST "$OLLAYA/api/decide" -H 'Content-Type: application/json' -d "$1"
}

q='"questions":{"urgent":{"type":"noul","instructions":"Is this urgent and business-critical?"},"team":{"type":"choice","criteria":{"infra":"Infrastructure outage or technical failure","billing":"Billing or payment issue","sales":"Sales or pricing inquiry"}}}'

post "{\"model\":\"laya:en\",\"state\":\"Production server is down, customers cannot log in, revenue impacted\",$q}" > canned/ticket-1-infra.json
post "{\"model\":\"laya:en\",\"state\":\"I was charged twice for my subscription this month\",$q}" > canned/ticket-2-billing.json
post "{\"model\":\"laya:en\",\"state\":\"Do you offer volume discounts for 500 seats?\",$q}" > canned/ticket-3-sales.json
post "{\"model\":\"laya:en\",\"state\":\"hmm\",$q}" > canned/ticket-4-hmm.json

echo "Captured 4 canned responses into ./canned/ - eyeball them, then commit."
