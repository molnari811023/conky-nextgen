#!/bin/bash
killall conky 2>/dev/null
sleep 0.5
cd "$(dirname "$0")"
conky -c conky.conf &
