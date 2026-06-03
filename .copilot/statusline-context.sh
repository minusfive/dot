#!/usr/bin/env bash

# Renders Copilot CLI context usage as a Unicode progress bar with a dark empty segment,
# plus a color-ramped filled segment and matching percentage text.
input=$(cat)

# Find the context usage percentage from known current-state paths only.
# Avoid recursive fallbacks that can select stale historical values.
used=$(
  jq -r '
    .context_window.used_percentage //
    .context_window.usedPercentage //
    .contextWindow.usedPercentage //
    .contextWindow.used_percentage //
    .context.used_percentage //
    .context.usedPercentage //
    .usage.context_window.used_percentage //
    .usage.contextWindow.usedPercentage //
    .usage.context_window.usedPercentage //
    0
  ' <<<"$input"
)

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

# Foreground transitions through a fixed 256-color ramp from 0-50%, then stays at the final color.
fg=$(awk -v p="$pct" 'BEGIN {
  if (p < 0) p = 0
  if (p > 100) p = 100
  # 256-color ramp: 006 -> 002 -> 003 -> 017 -> 016 -> 009.
  split("006 002 003 017 016 009", ramp, " ")
  if (p >= 50) {
    idx = ramp[6]
  } else {
    step = int((p / 50) * 5)
    idx = ramp[step + 1]
  }
  printf "\033[38;5;%dm", idx
}')

gray='\033[38;5;0m'

# Use a leading NBSP so display layers that trim ASCII leading spaces keep the left pad.
printf ' %b%s%%\033[0m %b%s%b%s\033[0m' "$fg" "$pct" "$fg" "$filled" "$gray" "$empty"
