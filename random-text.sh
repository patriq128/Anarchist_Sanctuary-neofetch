#!/usr/bin/env bash

texts=(
    "They burn my house to the ground..."
)

printf '%s\n' "${texts[RANDOM % ${#texts[@]}]}"
