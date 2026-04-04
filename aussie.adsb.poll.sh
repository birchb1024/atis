#!/bin/bash
set -euo pipefail

genyris aussie.adsb.2.g | tee -a data/$(date -u +%s).aussie.adsb.ymml.log

#tail -f data/1.stderr.aussie.adsb.ymml.log data/1.aussie.adsb.ymml.log &
