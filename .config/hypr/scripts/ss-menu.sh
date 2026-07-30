#!/usr/bin/env bash

choice=$(
    printf '%s\n' \
        'Capturar área' \
        'Capturar janela' \
        'Capturar monitor' |
    fuzzel --dmenu --prompt='Screenshot: '
)

case "$choice" in
    'Capturar área')
        hyprshot -m region
        ;;
    'Capturar janela')
        hyprshot -m window
        ;;
    'Capturar monitor')
        hyprshot -m output
        ;;
esac
