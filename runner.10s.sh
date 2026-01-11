#!/bin/bash

# <xbar.title>GitHub Actions Runner Monitor</xbar.title>
# <xbar.version>v1.0.0</xbar.version>
# <xbar.author>KindBear</xbar.author>
# <xbar.author.github>fkysly</xbar.author.github>
# <xbar.desc>Monitor and control GitHub Actions self-hosted runner from menu bar</xbar.desc>
# <xbar.image>https://raw.githubusercontent.com/fkysly/swiftbar-runner/main/screenshot.png</xbar.image>
# <xbar.dependencies>gh</xbar.dependencies>
# <xbar.abouturl>https://github.com/fkysly/swiftbar-runner</xbar.abouturl>

# ============================================
# Configuration
# ============================================
CONFIG_FILE="$HOME/.config/swiftbar-runner/config"

# Load config or use defaults
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Required settings (will prompt if not configured)
REPO="${REPO:-}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
SERVICE_NAME="${SERVICE_NAME:-}"

# Optional settings
GH="${GH:-$(which gh)}"
PLUGIN_DIR="${PLUGIN_DIR:-$HOME/Library/Application Support/SwiftBar/Plugins}"

# ============================================
# Setup check
# ============================================
SCRIPT_NAME=$(basename "$0")
CURRENT_INTERVAL=$(echo "$SCRIPT_NAME" | sed -E 's/runner\.([0-9]+)s\.sh/\1/')

# Check if configured
if [ -z "$REPO" ] || [ -z "$SERVICE_NAME" ]; then
    echo "⚠️"
    echo "---"
    echo "Setup Required | color=red"
    echo "---"
    echo "Create config file: | color=#666666"
    echo "~/.config/swiftbar-runner/config | color=#666666"
    echo "---"
    echo "Required settings: | size=12"
    echo "REPO=\"owner/repo\" | font=Menlo size=11"
    echo "SERVICE_NAME=\"actions.runner...\" | font=Menlo size=11"
    echo "RUNNER_DIR=\"/path/to/runner\" | font=Menlo size=11"
    echo "---"
    echo "📁 Create Config | bash=/bin/mkdir param1=-p param2=$HOME/.config/swiftbar-runner terminal=false"
    echo "📝 Find Service Name | bash=/bin/bash param1=-c param2='launchctl list | grep actions.runner | pbcopy && osascript -e \"display notification \\\"Service name copied to clipboard\\\" with title \\\"Runner Monitor\\\"\"' terminal=false"
    exit 0
fi

STATE_FILE="/tmp/runner_monitor_last_job_id"
PLIST_FILE="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"

# ============================================
# Status checks
# ============================================

# Check if runner is running
if launchctl list 2>/dev/null | grep -q "$SERVICE_NAME"; then
    RUNNER_STATUS="running"
else
    RUNNER_STATUS="stopped"
fi

# Get workflow runs and parse with Python
PARSED=$($GH run list --repo "$REPO" --limit 8 --json databaseId,status,conclusion,name,headBranch,url 2>/dev/null | /usr/bin/python3 -c "
import json
import sys
import subprocess
import re
import os

gh = os.environ.get('GH', 'gh')
repo = os.environ.get('REPO', '')

def get_version_from_jobs(run_id, workflow_name, branch):
    '''Try to extract version from job name like build (0.1.0-beta.2)'''
    if workflow_name != 'Release':
        return branch
    try:
        result = subprocess.run(
            [gh, 'run', 'view', str(run_id), '--repo', repo, '--json', 'jobs'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            jobs_data = json.loads(result.stdout)
            for job in jobs_data.get('jobs', []):
                job_name = job.get('name', '')
                match = re.search(r'\(([0-9]+\.[0-9]+\.[0-9]+[^\)]*)\)', job_name)
                if match:
                    return 'v' + match.group(1)
    except:
        pass
    return branch

try:
    runs = json.load(sys.stdin)
    in_progress_count = 0

    for r in runs:
        status = r.get('status', '')
        conclusion = r.get('conclusion', '')
        name = r.get('name', 'Unknown')
        branch = r.get('headBranch', '')
        url = r.get('url', '')
        run_id = r.get('databaseId', '')

        version = get_version_from_jobs(run_id, name, branch)

        if status == 'in_progress':
            in_progress_count += 1
            print(f'IN_PROGRESS:{name}|{version}|{url}|{run_id}')
        else:
            icon = '✅' if conclusion == 'success' else '❌' if conclusion == 'failure' else '⚪'
            print(f'COMPLETED:{icon}|{name}|{version}|{url}')

    print(f'COUNT:{in_progress_count}')
except Exception as e:
    print(f'ERROR:{e}', file=sys.stderr)
    print('COUNT:0')
")

# Extract count
IN_PROGRESS_COUNT=$(echo "$PARSED" | grep "^COUNT:" | cut -d: -f2)
IN_PROGRESS_COUNT=${IN_PROGRESS_COUNT:-0}

# ============================================
# Notifications
# ============================================
LATEST_ID=$($GH run list --repo "$REPO" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)

if [ -f "$STATE_FILE" ]; then
    LAST_ID=$(cat "$STATE_FILE")
    if [ "$LATEST_ID" != "$LAST_ID" ] && [ -n "$LATEST_ID" ]; then
        FIRST_LINE=$(echo "$PARSED" | grep -E "^(IN_PROGRESS|COMPLETED):" | head -1)
        if [ -n "$FIRST_LINE" ]; then
            TYPE=$(echo "$FIRST_LINE" | cut -d: -f1)
            INFO=$(echo "$FIRST_LINE" | cut -d: -f2-)
            if [ "$TYPE" = "IN_PROGRESS" ]; then
                JOB_NAME=$(echo "$INFO" | cut -d'|' -f1)
                JOB_VERSION=$(echo "$INFO" | cut -d'|' -f2)
            else
                JOB_NAME=$(echo "$INFO" | cut -d'|' -f2)
                JOB_VERSION=$(echo "$INFO" | cut -d'|' -f3)
            fi
            osascript -e "display notification \"$JOB_NAME $JOB_VERSION\" with title \"🚀 New Job Started\" sound name \"Glass\""
        fi
    fi
fi
echo "$LATEST_ID" > "$STATE_FILE"

# ============================================
# Menu bar display
# ============================================

# Menu bar icon (native macOS style - monochrome)
if [ "$RUNNER_STATUS" = "stopped" ]; then
    echo "○"
elif [ "$IN_PROGRESS_COUNT" -gt 0 ] 2>/dev/null; then
    echo "● $IN_PROGRESS_COUNT"
else
    echo "●"
fi

echo "---"

# Runner status
if [ "$RUNNER_STATUS" = "running" ]; then
    echo "Runner: ✅ Running | color=green"
else
    echo "Runner: ⏸ Stopped | color=red"
fi

echo "---"

# In-progress jobs
echo "🔄 Running Jobs | size=12 color=#666666"
IN_PROGRESS_LINES=$(echo "$PARSED" | grep "^IN_PROGRESS:")
if [ -z "$IN_PROGRESS_LINES" ]; then
    echo "   No running jobs | color=#888888"
else
    echo "$IN_PROGRESS_LINES" | while read -r line; do
        INFO=$(echo "$line" | cut -d: -f2-)
        NAME=$(echo "$INFO" | cut -d'|' -f1)
        VERSION=$(echo "$INFO" | cut -d'|' -f2)
        URL=$(echo "$INFO" | cut -d'|' -f3)
        echo "   🔵 $NAME ($VERSION) | href=$URL"
    done
fi

echo "---"

# Recent jobs
echo "📋 Recent Jobs | size=12 color=#666666"
COMPLETED_LINES=$(echo "$PARSED" | grep "^COMPLETED:" | head -5)
if [ -z "$COMPLETED_LINES" ]; then
    echo "   No recent jobs | color=#888888"
else
    echo "$COMPLETED_LINES" | while read -r line; do
        INFO=$(echo "$line" | cut -d: -f2-)
        ICON=$(echo "$INFO" | cut -d'|' -f1)
        NAME=$(echo "$INFO" | cut -d'|' -f2)
        VERSION=$(echo "$INFO" | cut -d'|' -f3)
        URL=$(echo "$INFO" | cut -d'|' -f4)
        echo "   $ICON $NAME ($VERSION) | href=$URL"
    done
fi

echo "---"

# Runner controls
if [ "$RUNNER_STATUS" = "running" ]; then
    echo "⏹ Stop Runner | bash='$RUNNER_DIR/svc.sh' param1=stop terminal=false refresh=true"
    echo "🔄 Restart Runner | bash='$RUNNER_DIR/svc.sh' param1=stop terminal=false"
else
    echo "▶️ Start Runner | bash='$RUNNER_DIR/svc.sh' param1=start terminal=false refresh=true"
fi

echo "---"
echo "📊 Open GitHub Actions | href=https://github.com/$REPO/actions"
echo "📁 Open Runner Folder | bash=/usr/bin/open param1=$RUNNER_DIR terminal=false"
echo "---"
echo "⚙️ Settings"
# Refresh interval submenu
echo "-- Refresh Interval (${CURRENT_INTERVAL}s)"
for interval in 5 10 30 60; do
    if [ "$interval" = "$CURRENT_INTERVAL" ]; then
        echo "---- ✓ ${interval}s | color=#666666"
    else
        echo "---- ${interval}s | bash=/bin/mv param1=\"$PLUGIN_DIR/$SCRIPT_NAME\" param2=\"$PLUGIN_DIR/runner.${interval}s.sh\" terminal=false refresh=true"
    fi
done
# Autostart toggle
if [ -f "$PLIST_FILE" ]; then
    echo "-- ✓ Launch at Login | bash='$RUNNER_DIR/svc.sh' param1=uninstall terminal=false refresh=true"
else
    echo "-- Launch at Login | bash='$RUNNER_DIR/svc.sh' param1=install terminal=false refresh=true"
fi
echo "-- Edit Config | bash=/usr/bin/open param1=-e param2=$CONFIG_FILE terminal=false"
echo "---"
echo "🔄 Refresh | refresh=true"
