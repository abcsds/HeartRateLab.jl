#!/bin/bash
# HeartRateLab Docker entrypoint script
# Handles both interactive and non-interactive Julia commands

set -e

# If arguments are provided, run them as a Julia command
if [ $# -gt 0 ]; then
    # Run Julia with the provided command
    exec /usr/local/julia/bin/julia --project=. "$@"
else
    # Interactive mode: start Julia REPL
    exec /usr/local/julia/bin/julia --project=. -i
fi
