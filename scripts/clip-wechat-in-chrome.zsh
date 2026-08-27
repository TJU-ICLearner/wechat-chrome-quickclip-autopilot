#!/bin/zsh
set -euo pipefail

vault_dir="${OBSIDIAN_VAULT_DIR:-${HOME}/Documents/SOC Learning}"
raw_dir="${OBSIDIAN_RAW_DIR:-$vault_dir/raw/articles}"
# Keep operational state in the vault so cc-connect's workspace-write sandbox
# can write it without granting the workflow access to unrelated directories.
log_file="$vault_dir/.claudian/logs/wechat-chrome-clipper.log"
lock_dir="$vault_dir/.claudian/wechat-chrome-clipper.lock"
url="${1:-}"
render_wait_seconds="${WECHAT_CLIP_WAIT_SECONDS:-5}"
poll_attempts="${WECHAT_CLIP_POLL_ATTEMPTS:-30}"

if [[ ! "$url" =~ '^https://mp\.weixin\.qq\.com/' ]]; then
  print -r -- '{"status":"error","reason":"expected an https mp.weixin.qq.com URL"}'
  exit 64
fi

if [[ ! "$render_wait_seconds" =~ '^[0-9]+$' || ! "$poll_attempts" =~ '^[1-9][0-9]*$' ]]; then
  print -r -- '{"status":"error","reason":"WECHAT_CLIP_WAIT_SECONDS and WECHAT_CLIP_POLL_ATTEMPTS must be positive integers"}'
  exit 64
fi

mkdir -p "$raw_dir" "${log_file:h}" "${lock_dir:h}"
if ! mkdir "$lock_dir" 2>/dev/null; then
  print -r -- '{"status":"busy","reason":"another WeChat clipping task is running"}'
  exit 75
fi
trap 'rmdir "$lock_dir"' EXIT

started_at="$(date '+%Y-%m-%d %H:%M:%S')"
print -r -- "[$started_at] clipping requested: $url" >> "$log_file"

# This intentionally uses the user's normal Chrome profile, where Obsidian Web
# Clipper is installed. Quick clip must already be configured to save directly
# to raw/articles.
if ! osascript - "$url" <<'APPLESCRIPT'
on run argv
  tell application "Google Chrome"
    activate
    open location (item 1 of argv)
  end tell
end run
APPLESCRIPT
then
  print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] Google Chrome unavailable" >> "$log_file"
  print -r -- '{"status":"chrome_unavailable","reason":"Open the normal Google Chrome profile with Obsidian Web Clipper, make it the frontmost window, then retry"}'
  exit 78
fi

# Keep the initial-release flow: wait a short, fixed interval then send the
# configured shortcut once. No page JavaScript or Chrome load-state inspection.
sleep "$render_wait_seconds"

if ! osascript <<'APPLESCRIPT'
tell application "Google Chrome" to activate
tell application "System Events"
  tell process "Google Chrome"
    keystroke "p" using {command down, shift down}
  end tell
end tell
APPLESCRIPT
then
  print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] accessibility permission required" >> "$log_file"
  print -r -- '{"status":"permission_required","reason":"Allow osascript or the calling app to control Google Chrome in macOS Accessibility settings"}'
  exit 77
fi

# Web Clipper writes asynchronously through Obsidian. Confirm the saved raw
# source by its original URL rather than guessing its title-derived filename.
for ((attempt = 1; attempt <= poll_attempts; attempt++)); do
  match="$(rg -l -F --glob '*.md' "$url" "$raw_dir" 2>/dev/null | head -1 || true)"
  if [[ -n "$match" && "$match" -nt "$lock_dir" ]]; then
    print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] clipped: $match" >> "$log_file"
    jq -n --arg path "$match" '{status:"captured", path:$path}'
    exit 0
  fi
  sleep 2
done

print -r -- "[$(date '+%Y-%m-%d %H:%M:%S')] no raw source detected: $url" >> "$log_file"
print -r -- '{"status":"pending","reason":"Quick clip was sent, but no matching raw note appeared within 60 seconds"}'
exit 1
