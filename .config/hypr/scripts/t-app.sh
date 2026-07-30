#!/usr/bin/env bash

MATCH="$1"
shift
COMMAND="$*"

ADDRESS="$(
    hyprctl clients -j |
    jq -r --arg match "$MATCH" '
        .[]
        | select(
            ((.class // "") | ascii_downcase | contains($match | ascii_downcase))
            or
            ((.initialClass // "") | ascii_downcase | contains($match | ascii_downcase))
            or
            ((.title // "") | ascii_downcase | contains($match | ascii_downcase))
        )
        | .address
    ' |
    head -n1
)"

if [[ -n "$ADDRESS" && "$ADDRESS" != "null" ]]; then
    hyprctl dispatch focuswindow "address:$ADDRESS"
else
    "$@" >/dev/null 2>&1 &
fi
