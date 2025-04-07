#!/bin/bash

set -euo pipefail

curl -v -X GET http://127.0.0.1/fibonacci -H "Content-Type: application/json" -d '{"number": 93}'
