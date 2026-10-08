#!/usr/bin/env bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Short directory display
dir=""
[ -n "$cwd" ] && dir="${cwd/#$HOME/~}"

# Git branch with status color
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch_name=$(git -C "$cwd" -c core.hooksPath=/dev/null symbolic-ref --short HEAD 2>/dev/null ||
        git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch_name" ]; then
        status_out=$(git -C "$cwd" status --porcelain 2>/dev/null)
        if echo "$status_out" | grep -qE '^(UU|AA|DD|U[ADM]|[ADM]U)'; then
            bcolor='\033[31m' # red: conflicts
        elif [ -z "$status_out" ]; then
            bcolor='\033[32m' # green: clean
        else
            bcolor='\033[33m' # yellow: dirty
        fi
        branch=$(printf '%b %s\033[0m' "$bcolor" "$branch_name")
    fi
fi

# Dir + branch (one section)
dir_branch="$dir"
[ -n "$branch" ] && dir_branch="$dir$branch"

# Effort color-coded
effort_str=""
if [ -n "$effort" ]; then
    case "$effort" in
        low) ecolor='\033[32m' ;;    # green
        medium) ecolor='\033[33m' ;; # yellow
        high) ecolor='\033[31m' ;;   # red
        *) ecolor='\033[37m' ;;
    esac
    effort_str=$(printf '%b%s\033[0m' "$ecolor" "$effort")
fi

# Model color-coded by cost tier: haiku=green, sonnet=yellow, opus=red
case "$(echo "$model" | tr '[:upper:]' '[:lower:]')" in
    *haiku*) mcolor='\033[32m' ;;
    *sonnet*) mcolor='\033[33m' ;;
    *opus*) mcolor='\033[31m' ;;
    *) mcolor='\033[37m' ;;
esac
model_colored=$(printf '%b%s\033[0m' "$mcolor" "$model")


# Context as unicode progress bar (10 cells, eighth-block resolution)
ctx=""
if [ -n "$used" ]; then
    eighths=$(awk -v u="$used" 'BEGIN { e = u * 0.8 + 0.5; if (e > 80) e = 80; if (e < 0) e = 0; printf "%d", e }')
    full=$((eighths / 8))
    rem=$((eighths % 8))
    filled=""
    for ((i = 0; i < full; i++)); do filled+="█"; done
    if [ "$rem" -gt 0 ]; then
        case "$rem" in
            1) filled+="▏" ;;
            2) filled+="▎" ;;
            3) filled+="▍" ;;
            4) filled+="▌" ;;
            5) filled+="▋" ;;
            6) filled+="▊" ;;
            7) filled+="▉" ;;
        esac
        empty_count=$((10 - full - 1))
    else
        empty_count=$((10 - full))
    fi
    empty=""
    for ((i = 0; i < empty_count; i++)); do empty+="░"; done

    # Color by usage: <33% green, <50% yellow, >=50% red
    ctx_color=$(awk -v u="$used" 'BEGIN {
        if (u >= 50) print "\033[31m"
        else if (u >= 33) print "\033[33m"
        else print "\033[32m"
    }')
    gray='\033[38;5;238m'
    pct=$(printf '%.0f' "$used")
    ctx=$(printf '%b%s%b%s\033[0m %b%s%%\033[0m' "$ctx_color" "$filled" "$gray" "$empty" "$ctx_color" "$pct")
fi

# Cost: session and monthly total, no labels.
# State is keyed by session_id so concurrent sessions don't double-count;
# monthly total is the sum of all per-session entries for the current month.
cost_str=""
state_file="$HOME/.claude/monthly-usage.json"
lock_dir="${state_file}.lock"

if [ -n "$cost" ]; then
    session_id=$(echo "$input" | jq -r '.session_id // empty')
    cur_month=$(date +%Y-%m)

    lock_acquired=0
    for _ in $(seq 1 25); do
        if mkdir "$lock_dir" 2>/dev/null; then
            lock_acquired=1
            break
        fi
        sleep 0.02
    done

    # Break stale lock from a crashed prior invocation (>5s old).
    if [ "$lock_acquired" -eq 0 ] && [ -d "$lock_dir" ]; then
        lock_mtime=$(stat -f %m "$lock_dir" 2>/dev/null || echo 0)
        if [ $(($(date +%s) - lock_mtime)) -gt 5 ]; then
            rmdir "$lock_dir" 2>/dev/null
            mkdir "$lock_dir" 2>/dev/null && lock_acquired=1
        fi
    fi

    [ "$lock_acquired" -eq 1 ] && trap 'rmdir "$lock_dir" 2>/dev/null' EXIT

    state_month=""
    sessions_json="{}"
    if [ -f "$state_file" ]; then
        state_month=$(jq -r '.month // ""' "$state_file" 2>/dev/null)
        sj=$(jq -c '.sessions // {}' "$state_file" 2>/dev/null)
        [ -n "$sj" ] && sessions_json="$sj"
    fi

    [ "$state_month" != "$cur_month" ] && sessions_json="{}"

    if [ -n "$session_id" ]; then
        # Track base offset per session so inherited costs after /clear are excluded.
        # New session_id: base=current cost (inherited value), max=current cost → net $0.
        # Existing session: only update max (preserves the base offset).
        # Flat numbers from old format: treated as base=0 for backward compat.
        sessions_json=$(jq -c --arg sid "$session_id" --argjson c "$cost" '
          if has($sid) then
            .[$sid] = (.[$sid] | if type == "object"
              then .max = ([.max, $c] | max)
              else {"base": 0, "max": ([., $c] | max)}
              end)
          else
            .[$sid] = {"base": $c, "max": $c}
          end
        ' <<<"$sessions_json")

        if [ "$lock_acquired" -eq 1 ]; then
            tmp_state=$(mktemp "${state_file}.XXXXXX")
            jq -n --arg m "$cur_month" --argjson s "$sessions_json" \
                '{ month: $m, sessions: $s }' >"$tmp_state" && mv "$tmp_state" "$state_file"
        fi
    fi

    monthly_total=$(jq -r '[to_entries[].value | if type == "object" then .max - .base else . end] | add // 0' <<<"$sessions_json")
    cost_str=$(printf '$%.2f ($%.2f)' "$cost" "$monthly_total")

    if [ "$lock_acquired" -eq 1 ]; then
        rmdir "$lock_dir" 2>/dev/null
        trap - EXIT
    fi
fi

# Build status line — row 1: context | model | effort | cost, row 2: dir branch
row1=()
[ -n "$ctx" ] && row1+=("$ctx")
[ -n "$model_colored" ] && row1+=("$model_colored")
[ -n "$effort_str" ] && row1+=("$effort_str")
[ -n "$cost_str" ] && row1+=("$cost_str")

line1=""
for p in "${row1[@]}"; do
    [ -n "$line1" ] && line1+=" | "
    line1+="$p"
done

output="$line1"
[ -n "$dir_branch" ] && output+=$'\n'"$dir_branch"

printf '%s' "$output"
