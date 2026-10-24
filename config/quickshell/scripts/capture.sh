#!/usr/bin/env bash
# Helper for Quickshell screenshot & screen recording (services/Recorder.qml).
set -u

find_bin() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        command -v "$name"
        return 0
    fi
    local p
    p=$(ls -d /nix/store/*-"${name}"-*/bin/"${name}" 2>/dev/null | tail -n 1 || true)
    if [ -n "$p" ] && [ -x "$p" ]; then
        echo "$p"
        return 0
    fi
    return 1
}

get_focused_monitor() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' | head -n 1
}

get_window_geometry() {
    local ws_ids
    ws_ids=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].activeWorkspace.id')
    local boxes
    boxes=$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')" '
        .[] | select(.mapped == true and .hidden == false and (.workspace.id as $w | $ws | index($w))) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.title)"
    ')
    if [ -n "$boxes" ]; then
        echo "$boxes" | slurp -r
    else
        slurp
    fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
    shot)
        mode="${1:-region}"       # region | window | output
        action="${2:-copy}"       # copy | save | annotate
        delay="${3:-0}"           # seconds
        sleep 0.25                # let overlay close

        geom=""
        mon=""
        if [ "$mode" = "region" ]; then
            geom=$(slurp 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        elif [ "$mode" = "window" ]; then
            geom=$(get_window_geometry 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        else
            mon=$(get_focused_monitor)
        fi

        if [ "${delay:-0}" -gt 0 ] 2>/dev/null; then
            sleep "$delay"
        fi

        ts=$(date +"%Y-%m-%d_%H-%M-%S")
        shot_dir="$HOME/Pictures/Screenshots"
        mkdir -p "$shot_dir"
        tmp_file="/tmp/hcs_screenshot_${ts}.png"

        if [ -n "$geom" ]; then
            grim -g "$geom" "$tmp_file" || exit 1
        elif [ -n "$mon" ]; then
            grim -o "$mon" "$tmp_file" || grim "$tmp_file" || exit 1
        else
            grim "$tmp_file" || exit 1
        fi

        wl-copy --type image/png < "$tmp_file" 2>/dev/null || true

        if [ "$action" = "save" ]; then
            dest="$shot_dir/Screenshot_${ts}.png"
            cp "$tmp_file" "$dest"
            rm -f "$tmp_file"
            notify-send -a "Screenshot" -i camera-photo "Screenshot saved & copied" "$dest" 2>/dev/null || true
        elif [ "$action" = "annotate" ]; then
            swappy_bin=$(find_bin swappy || true)
            if [ -n "$swappy_bin" ]; then
                "$swappy_bin" -f "$tmp_file" -o "$shot_dir/Screenshot_${ts}.png"
                rm -f "$tmp_file"
            else
                dest="$shot_dir/Screenshot_${ts}.png"
                cp "$tmp_file" "$dest"
                rm -f "$tmp_file"
                notify-send -a "Screenshot" -i camera-photo "Screenshot saved & copied" "$dest" 2>/dev/null || true
            fi
        else
            rm -f "$tmp_file"
            notify-send -a "Screenshot" -i edit-copy "Screenshot copied" "Copied to clipboard" 2>/dev/null || true
        fi
        ;;

    record)
        mode="${1:-screen}"       # screen | region | window
        audio="${2:-none}"        # none | system | mic
        sleep 0.25                # let overlay close

        geom=""
        mon=""
        if [ "$mode" = "region" ]; then
            geom=$(slurp 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        elif [ "$mode" = "window" ]; then
            geom=$(get_window_geometry 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        else
            mon=$(get_focused_monitor)
        fi

        rec_dir="$HOME/Videos/Recordings"
        mkdir -p "$rec_dir"
        ts=$(date +"%Y-%m-%d_%H-%M-%S")
        out_file="$rec_dir/Recording_${ts}.mp4"

        wf_bin=$(find_bin wf-recorder || true)
        wl_bin=$(find_bin wl-screenrec || true)

        audio_dev=""
        if [ "$audio" = "system" ]; then
            sink=$(pactl get-default-sink 2>/dev/null || true)
            [ -n "$sink" ] && audio_dev="${sink}.monitor"
        elif [ "$audio" = "mic" ]; then
            audio_dev=$(pactl get-default-source 2>/dev/null || true)
        fi

        echo "STARTED:$out_file"

        if [ -n "$wf_bin" ]; then
            args=(-f "$out_file" -y)
            [ -n "$geom" ] && args+=(-g "$geom")
            [ -z "$geom" ] && [ -n "$mon" ] && args+=(-o "$mon")
            if [ "$audio" != "none" ]; then
                if [ -n "$audio_dev" ]; then
                    args+=("--audio=$audio_dev")
                else
                    args+=(--audio)
                fi
            fi
            "$wf_bin" "${args[@]}" >/dev/null 2>&1
        elif [ -n "$wl_bin" ]; then
            args=(-f "$out_file")
            [ -n "$geom" ] && args+=(-g "$geom")
            [ -z "$geom" ] && [ -n "$mon" ] && args+=(-o "$mon")
            if [ "$audio" != "none" ]; then
                args+=(--audio)
                [ -n "$audio_dev" ] && args+=(--audio-device "$audio_dev")
            fi
            "$wl_bin" "${args[@]}" >/dev/null 2>&1
        else
            notify-send -a "Screen Recorder" -u critical "Screen recorder missing" "Install wf-recorder or wl-screenrec"
            exit 1
        fi

        if [ -f "$out_file" ]; then
            printf "file://%s\r\n" "$out_file" | wl-copy --type text/uri-list 2>/dev/null || true
            notify-send -a "Screen Recorder" -i media-record "Recording saved" "$out_file (copied file to clipboard)" 2>/dev/null || true
        fi
        ;;
esac
