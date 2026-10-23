#!/bin/sh
#
# Base44 sandbox helper for the Pegasus Dashboard (pegasus-service).
#
#   run <cmd...>   prepare the sandbox and run <cmd...> as the "pegasus" user
#   probe          healthcheck: probe the dashboard as the "pegasus" user
#
set -e

USAGE="usage: $0 {run <cmd...>|probe}"

prepare() {
    # The bind-mounted checkout is root-owned with restrictive permissions;
    # grant the unprivileged service user read/traverse access to the parts the
    # service imports and to this directory's helper scripts.
    chmod a+rx /pegasus
    chmod -R a+rX /pegasus/packages /pegasus/.base44

    # Single-user sandbox configuration: no login prompt, no privilege
    # switching, plain HTTP (the preview proxy terminates TLS). Only applied
    # when the platform says we are in preview mode; otherwise the service
    # keeps its default configuration.
    if [ "$BASE44_PREVIEW_MODE" = "1" ]; then
        mkdir -p /home/pegasus/.pegasus
        cat > /home/pegasus/.pegasus/service.py <<'PY'
# Written by .base44/entrypoint.sh: single-user preview configuration.
AUTHENTICATION = "NoAuthentication"
PROCESS_SWITCHING = False
SSL_ENABLED = False
PY
        chown -R pegasus:pegasus /home/pegasus/.pegasus
    fi
}

case "$1" in
    run)
        shift
        prepare
        exec su pegasus -s /bin/sh -c "exec $*"
        ;;
    probe)
        # The service refuses requests from uid 0, so probe as "pegasus".
        exec su pegasus -c "python3 -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:5000/u/pegasus/\", timeout=5)'"
        ;;
    *)
        echo "$USAGE" >&2
        exit 2
        ;;
esac
