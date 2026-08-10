#!/bin/bash
# HeartRateLab Docker entrypoint script
# Handles both interactive and non-interactive Julia commands

# If arguments are provided, treat them as a shell command
if [ $# -gt 0 ]; then
    # Execute the provided command using bash -c to properly parse it
    exec bash -c "$@"
else
    # Interactive mode: start Julia REPL
    exec /usr/local/julia/bin/julia --project=. -i
fi
