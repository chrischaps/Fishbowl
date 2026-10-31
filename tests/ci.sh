#!/usr/bin/env sh
# Everything CI checks, runnable at home too:
#
#   LOVE=lovec sh tests/ci.sh                         (from the repo root)
#   LOVE=... xvfb-run -a sh tests/ci.sh               (Linux with no screen)
#   LOVE=... WINDOW="xvfb-run -a" sh tests/ci.sh      (...or a screen for each run)
#   GAME=dist/fishbowl.love sh tests/ci.sh            (check the packed tank)
#
# 1. The self-test in a window, as on a desktop.
# 2. The self-test on the frame (--frame): fullscreen, borderless, no
#    cursor, and a finger instead of a mouse. This is the smoke test Easel
#    runs before it trusts a release.
# 3. On Linux, the frame ended the way Easel ends it: SIGTERM, which SDL
#    turns into love.quit. It must exit 0, inside Easel's grace, having
#    written the tank. It must say EASEL_READY first.

cd "$(dirname "$0")/.." || exit 1
LOVE=${LOVE:-lovec}
GAME=${GAME:-.}
GRACE=${GRACE:-5} # seconds: the grace Easel gives an app that names none
failed=0

selftest() {
    out=$($WINDOW "$LOVE" "$GAME" --selftest "$@" 2>&1)
    status=$?
    echo "$out"
    if [ "$status" = 0 ] && echo "$out" | grep -q '^\[selftest\] all checks held'; then
        echo "selftest $*: passed"
    else
        echo "selftest $*: FAIL, exit $status"
        failed=1
    fi
}

echo "== the self-test, in a window"
selftest

echo "== the self-test, on the frame"
selftest --frame

if [ "$(uname -s)" = Linux ]; then
    echo "== the frame, ended as Easel ends it"
    home=$(mktemp -d) || exit 1
    # LÖVE keeps the tank in $XDG_DATA_HOME/love/Fishbowl: an empty one here,
    # so the tank there can only have come from the quit
    XDG_DATA_HOME="$home" $WINDOW sh -c '
        "$1" "$2" --frame > "$3/log" 2>&1 &
        pid=$!
        i=0
        until grep -q "^EASEL_READY" "$3/log" || [ $i -ge 120 ]; do sleep 0.5; i=$((i + 1)); done
        sleep 3
        start=$(date +%s.%N)
        kill -TERM $pid
        wait $pid
        status=$?
        awk -v a="$(date +%s.%N)" -v b="$start" "BEGIN { printf \"%.2f\", a - b }" > "$3/took"
        exit $status' sh "$LOVE" "$GAME" "$home"
    status=$?
    cat "$home/log"
    took=$(cat "$home/took" 2>/dev/null)
    tank="$home/love/Fishbowl/tank.lua"
    if ! grep -q '^EASEL_READY' "$home/log"; then
        echo "frame: FAIL it never said EASEL_READY"
        failed=1
    elif [ "$status" = 0 ] && [ -s "$tank" ] && grep -q '"name"' "$tank" &&
        awk -v t="$took" -v g="$GRACE" "BEGIN { exit !(t < g) }"; then
        echo "frame: SIGTERM saved $(grep -c '"name"' "$tank") fish and quit cleanly in ${took}s (grace ${GRACE}s)"
    else
        echo "frame: FAIL SIGTERM exited $status after ${took:-?}s; the tank: $(ls -R "$home/love" 2>&1)"
        failed=1
    fi
    rm -rf "$home"
fi

[ "$failed" = 0 ] && echo "ci: all green"
exit $failed
