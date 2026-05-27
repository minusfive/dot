#!/usr/bin/env bash

# Renders Copilot CLI context usage as a Unicode progress bar with gray background,
# color-coded foreground and matching percentage text (green <45%, orange 45-59%, red >=60%).
input=$(cat)

# Find the context usage percentage from known paths and broad fallbacks.
used=$(
  jq -r '
    .context_window.used_percentage //
    .contextWindow.usedPercentage //
    .contextWindow.used_percentage //
    .context.used_percentage //
    .context.usedPercentage //
    .usage.context_window.used_percentage //
    .usage.contextWindow.usedPercentage //
    ([.. | objects | .used_percentage? // empty] | first) //
    ([.. | objects | .usedPercentage? // empty] | first) //
    empty
  ' <<<"$input"
)

[ -z "$used" ] && exit 0

pct=$(awk -v u="$used" 'BEGIN { p = u + 0; if (p < 0) p = 0; if (p > 100) p = 100; printf "%.0f", p }')

# 10 cells with 1/8th character resolution => 80 eighths max.
eighths=$(awk -v p="$pct" 'BEGIN { e = p * 0.8 + 0.5; if (e < 0) e = 0; if (e > 80) e = 80; printf "%d", e }')
full=$((eighths / 8))
rem=$((eighths % 8))

filled=""
for ((i = 0; i < full; i++)); do
  filled+="█"
done

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
for ((i = 0; i < empty_count; i++)); do
  empty+="█"
done

# Foreground transitions gradually from green (0%) to red (50%), then stays red.
fg=$(awk -v p="$pct" 'BEGIN {
  if (p < 0) p = 0
  if (p > 100) p = 100
  # 256-color ramp from green -> cyan -> blue -> teal -> deep blue -> maroon -> red.
  split("008 006 002 003 017 016 009", ramp, " ")
  if (p >= 50) {
    idx = ramp[7]
  } else {
    step = int((p / 50) * 6)
    idx = ramp[step + 1]
  }
  printf "\033[38;5;%dm", idx
}')

gray='\033[38;5;0m'

# Print one leading space before percentage, then one separator space before bar.
printf ' %b%s%%\033[0m %b%s%b%s\033[0m' "$fg" "$pct" "$fg" "$filled" "$gray" "$empty"
