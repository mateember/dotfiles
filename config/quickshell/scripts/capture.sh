#!/usr/bin/env bash
# Helper for Quickshell screenshot & screen recording (services/Recorder.qml).
set -u

PIDFILE="/tmp/hcs_recorder.pid"

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
    local boxes
    boxes=$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')" '
        .[] | select(.mapped == true and .hidden == false and (.workspace.id as $w | $ws | index($w))) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ')
    if [ -n "$boxes" ]; then
        printf "%s\n" "$boxes" | slurp -r 2>/dev/null
    else
        slurp < /dev/null 2>/dev/null
    fi
}

stop_active_recorder() {
    pkill -x slurp 2>/dev/null || true
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill -INT "$pid" 2>/dev/null || true
        fi
        rm -f "$PIDFILE"
    fi
    pkill -INT -x wf-recorder 2>/dev/null || true
    pkill -INT -x wl-screenrec 2>/dev/null || true
}

finalize_shot() {
    local tmp_file="$1"
    local action="${2:-copy}"
    local annotate_mode="${3:-region}"
    local ts shot_dir dest satty_bin swappy_bin
    ts=$(date +"%Y-%m-%d_%H-%M-%S")
    shot_dir="$HOME/Pictures/Screenshots"
    mkdir -p "$shot_dir"

    wl-copy --type image/png < "$tmp_file" 2>/dev/null || true

    if [ "$action" = "save" ]; then
        dest="$shot_dir/Screenshot_${ts}.png"
        cp "$tmp_file" "$dest"
        rm -f "$tmp_file"
        notify-send -a "Screenshot" -i camera-photo "Screenshot saved & copied" "$dest" 2>/dev/null || true
    elif [ "$action" = "annotate" ]; then
        satty_bin=$(find_bin satty || true)
        swappy_bin=$(find_bin swappy || true)
        if [ -n "$satty_bin" ]; then
            local satty_args=(
                --filename "$tmp_file"
                --output-filename "$shot_dir/Screenshot_${ts}.png"
                --copy-command wl-copy
                --early-exit
                --actions-on-enter save-to-clipboard
                --actions-on-escape exit
                --font-family "Fira Sans"
            )
            if [ "$annotate_mode" = "output" ]; then
                satty_args+=(--fullscreen current-screen --initial-tool crop)
            elif [ "$annotate_mode" = "cropped" ]; then
                satty_args+=(--resize smart --initial-tool pointer)
            else
                satty_args+=(--resize smart --initial-tool crop)
            fi
            "$satty_bin" "${satty_args[@]}" < /dev/null
            rm -f "$tmp_file"
        elif [ -n "$swappy_bin" ]; then
            "$swappy_bin" -f "$tmp_file" -o "$shot_dir/Screenshot_${ts}.png" < /dev/null
            rm -f "$tmp_file"
        else
            dest="$shot_dir/Screenshot_${ts}.png"
            cp "$tmp_file" "$dest"
            rm -f "$tmp_file"
            notify-send -a "Screenshot" -i camera-photo "Screenshot saved & copied" "$dest" 2>/dev/null || true
        fi
    else
        rm -f "$tmp_file"
        notify-send -a "Screenshot" -i camera-photo "Screenshot copied" "Copied to clipboard" 2>/dev/null || true
    fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
    stop)
        stop_active_recorder
        ;;

    freeze)
        session_dir="${1:-}"
        [ -z "$session_dir" ] && exit 1
        mkdir -p "$session_dir"

        monitors_json=$(hyprctl monitors -j 2>/dev/null || echo '[]')
        clients_json=$(hyprctl clients -j 2>/dev/null || echo '[]')
        cursor_json=$(hyprctl cursorpos -j 2>/dev/null || echo '{"x":0,"y":0}')

        while IFS= read -r mon; do
            [ -n "$mon" ] || continue
            grim -l 0 -o "$mon" "$session_dir/${mon}.png" &
        done < <(printf '%s' "$monitors_json" | jq -r '.[] | select(.disabled == false) | .name')
        wait

        jq -n \
            --arg sessionDir "$session_dir" \
            --argjson monitors "$monitors_json" \
            --argjson clients "$clients_json" \
            --argjson cursor "$cursor_json" \
            '
            ($monitors | map(select(.disabled == false)) | map(
                ((.transform // 0) % 2 == 1) as $rot |
                (if .scale > 0 then .scale else 1 end) as $scale |
                (if $rot then .height else .width end) as $physW |
                (if $rot then .width else .height end) as $physH |
                {
                    id: .id,
                    name: .name,
                    x: .x,
                    y: .y,
                    physW: $physW,
                    physH: $physH,
                    scale: $scale,
                    logW: ($physW / $scale),
                    logH: ($physH / $scale),
                    activeWsId: (.activeWorkspace.id // 0),
                    specialWsId: (.specialWorkspace.id? // 0),
                    focused: (.focused == true)
                }
            )) as $mons |
            ($mons | map({key: (.id | tostring), value: .}) | from_entries) as $monMap |
            [
                $clients[]
                | select(.mapped == true and .hidden == false)
                | ($monMap[(.monitor | tostring)]) as $m
                | select($m != null)
                | (.workspace.id // 0) as $ws
                | select($ws == $m.activeWsId or ($m.specialWsId != 0 and $ws == $m.specialWsId))
                | (.at[0] - $m.x) as $rx0
                | (.at[1] - $m.y) as $ry0
                | ($rx0 + .size[0]) as $rx1
                | ($ry0 + .size[1]) as $ry1
                | (if $rx0 < 0 then 0 else $rx0 end) as $cx0
                | (if $ry0 < 0 then 0 else $ry0 end) as $cy0
                | (if $rx1 > $m.logW then $m.logW else $rx1 end) as $cx1
                | (if $ry1 > $m.logH then $m.logH else $ry1 end) as $cy1
                | ($cx1 - $cx0) as $w
                | ($cy1 - $cy0) as $h
                | select($w > 4 and $h > 4)
                | {
                    address: .address,
                    title: (.title // ""),
                    className: (.class // ""),
                    monitorName: $m.name,
                    x: $cx0,
                    y: $cy0,
                    w: $w,
                    h: $h,
                    isSpecial: ($m.specialWsId != 0 and $ws == $m.specialWsId),
                    floating: (.floating == true),
                    focusOrder: (.focusHistoryID // 9999)
                }
            ] | sort_by([ (if .isSpecial then 0 else 1 end), (if .floating then 0 else 1 end), .focusOrder ]) as $wins |
            {
                sessionDir: $sessionDir,
                focusedMonitor: (($mons | map(select(.focused)) | .[0].name) // ($mons[0].name // "")),
                monitors: $mons,
                windows: $wins,
                cursor: $cursor
            }
            '
        ;;

    commit)
        src_png="${1:-}"
        px="${2:-0}"
        py="${3:-0}"
        pw="${4:-0}"
        ph="${5:-0}"
        is_full="${6:-0}"
        action="${7:-copy}"
        session_dir="${8:-}"

        tmp_file="/tmp/hcs_screenshot_$(date +%Y-%m-%d_%H-%M-%S)_$$.png"
        if [ -f "$src_png" ]; then
            if [ "$is_full" = "1" ]; then
                cp "$src_png" "$tmp_file" || exit 1
            else
                ffmpeg_bin=$(find_bin ffmpeg || true)
                if [ -n "$ffmpeg_bin" ]; then
                    "$ffmpeg_bin" -y -loglevel error -i "$src_png" -vf "crop=${pw}:${ph}:${px}:${py}" -frames:v 1 "$tmp_file" || exit 1
                else
                    cp "$src_png" "$tmp_file" || exit 1
                fi
            fi
        fi

        case "$session_dir" in
            /tmp/hcs_snip_*) rm -rf "$session_dir" ;;
        esac

        [ -f "$tmp_file" ] || exit 1
        finalize_shot "$tmp_file" "$action" "cropped"
        ;;

    shot)
        mode="${1:-region}"       # region | window | output
        action="${2:-copy}"       # copy | save | annotate
        delay="${3:-0}"           # seconds (after selection)
        pre_wait="${4:-0.25}"     # seconds before capture (let overlay close)
        pkill -x slurp 2>/dev/null || true
        if [ "$pre_wait" != "0" ] && [ "$pre_wait" != "0.0" ]; then
            sleep "$pre_wait"
        fi

        geom=""
        mon=""
        if [ "$mode" = "region" ]; then
            geom=$(slurp < /dev/null 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        elif [ "$mode" = "window" ]; then
            geom=$(get_window_geometry) || exit 0
            [ -z "$geom" ] && exit 0
        else
            mon=$(get_focused_monitor)
        fi

        if [ "${delay:-0}" -gt 0 ] 2>/dev/null; then
            sleep "$delay"
        fi

        tmp_file="/tmp/hcs_screenshot_$(date +%Y-%m-%d_%H-%M-%S)_$$.png"

        if [ -n "$geom" ]; then
            grim -g "$geom" "$tmp_file" || exit 1
        elif [ -n "$mon" ]; then
            grim -o "$mon" "$tmp_file" || grim "$tmp_file" || exit 1
        else
            grim "$tmp_file" || exit 1
        fi

        finalize_shot "$tmp_file" "$action" "$mode"
        ;;

    record)
        mode="${1:-screen}"       # screen | region | window
        audio="${2:-none}"        # none | system | mic

        stop_active_recorder
        sleep 0.25                # let overlay close

        geom=""
        mon=""
        if [ "$mode" = "region" ]; then
            geom=$(slurp < /dev/null 2>/dev/null) || exit 0
            [ -z "$geom" ] && exit 0
        elif [ "$mode" = "window" ]; then
            geom=$(get_window_geometry) || exit 0
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
            "$wf_bin" "${args[@]}" < /dev/null >/dev/null 2>&1 &
            rec_pid=$!
        elif [ -n "$wl_bin" ]; then
            args=(-f "$out_file")
            [ -n "$geom" ] && args+=(-g "$geom")
            [ -z "$geom" ] && [ -n "$mon" ] && args+=(-o "$mon")
            if [ "$audio" != "none" ]; then
                args+=(--audio)
                [ -n "$audio_dev" ] && args+=(--audio-device "$audio_dev")
            fi
            "$wl_bin" "${args[@]}" < /dev/null >/dev/null 2>&1 &
            rec_pid=$!
        else
            notify-send -a "Screen Recorder" -u critical "Screen recorder missing" "Install wf-recorder or wl-screenrec"
            exit 1
        fi

        echo "$rec_pid" > "$PIDFILE"
        trap 'kill -INT "$rec_pid" 2>/dev/null || true; rm -f "$PIDFILE"' INT TERM

        echo "STARTED:$out_file"
        wait "$rec_pid" 2>/dev/null || true
        rm -f "$PIDFILE"

        if [ -f "$out_file" ]; then
            printf "file://%s\r\n" "$out_file" | wl-copy --type text/uri-list 2>/dev/null || true
            notify-send -a "Screen Recorder" -i camera-video "Recording saved" "$out_file (copied file to clipboard)" 2>/dev/null || true
        fi
        ;;
esac
