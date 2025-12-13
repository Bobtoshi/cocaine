#!/bin/bash
# Script to cancel old queued/running GitHub Actions workflows
# Requires: gh CLI tool (install: brew install gh or https://cli.github.com)
# Usage: ./cancel-old-runs.sh

echo "Canceling old GitHub Actions runs..."
echo ""

# Cancel all queued/running runs older than 1 hour
gh run list --limit 100 --json databaseId,status,createdAt --jq '.[] | select(.status == "queued" or .status == "in_progress") | select((.createdAt | fromdateiso8601) < (now - 3600)) | .databaseId' | while read run_id; do
    if [ ! -z "$run_id" ]; then
        echo "Canceling run $run_id..."
        gh run cancel $run_id
    fi
done

echo ""
echo "Done! Check status with: gh run list"

