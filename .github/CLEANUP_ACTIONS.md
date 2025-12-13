# Cleaning Up Old GitHub Actions

If you have lots of old queued/running actions clogging your GitHub Actions queue, here's how to clean them up:

## Method 1: Via GitHub Web Interface (Easiest)

1. Go to your repository: https://github.com/Bobtoshi/cocaine
2. Click on the **"Actions"** tab
3. You'll see a list of all workflow runs
4. For each queued/running action you want to cancel:
   - Click on the workflow run
   - Click the **"..."** menu (three dots) in the top right
   - Select **"Cancel workflow run"**

## Method 2: Cancel All Old Runs at Once

1. Install GitHub CLI if you don't have it:
   ```bash
   brew install gh  # macOS
   # or download from https://cli.github.com
   ```

2. Authenticate:
   ```bash
   gh auth login
   ```

3. Run the cleanup script:
   ```bash
   ./.github/scripts/cancel-old-runs.sh
   ```

## Method 3: Manual GitHub CLI Commands

```bash
# List all runs
gh run list

# Cancel a specific run (replace RUN_ID)
gh run cancel RUN_ID

# Cancel all queued runs
gh run list --status queued --json databaseId --jq '.[].databaseId' | xargs -I {} gh run cancel {}
```

## What Changed

The workflows have been optimized to:
- Only run on `main` branch pushes (not feature branches)
- Skip builds when only documentation/markdown files change
- Skip builds when only `mine.sh` or `MINING_WINDOWS.md` change

This should significantly reduce the number of queued actions going forward.

