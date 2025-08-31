#!/usr/bin/env bash

list_trash_dirs() {
    local uid xdg_data_home
    uid="$(id -u)"
    xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

    # Helper: check if dir exists and is not empty
    non_empty_dir() {
        [ -d "$1" ] && [ "$(ls -A "$1" 2>/dev/null)" ]
    }

    # 1. User's home trash
    if non_empty_dir "$xdg_data_home/Trash"; then
        echo "$xdg_data_home/Trash"
    fi

    # 2. Per-mount trash dirs
    while read -r _ mountpoint fstype _; do
        # Skip non-local filesystems
        case "$fstype" in
            tmpfs|proc|sysfs|devtmpfs|cgroup*|overlay) continue ;;
        esac

        # .Trash
        if non_empty_dir "$mountpoint/.Trash"; then
            echo "$mountpoint/.Trash"
        fi

        # .Trash-$UID
        if non_empty_dir "$mountpoint/.Trash-$uid"; then
            echo "$mountpoint/.Trash-$uid"
        fi
    done < <(mount | awk '{print $1, $3, $5, $6}')
}

trash_usage_total() {
    local total
    total=$(list_trash_dirs | xargs -d '\n' du -sb 2>/dev/null | awk '{sum+=$1} END {print sum}')
    echo "$total"
}

bytes=$(trash_usage_total)
echo "Total trash usage: $bytes bytes ($(numfmt --to=iec "$bytes"))"