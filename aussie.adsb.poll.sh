#!/bin/bash
set -euo pipefail

./aussie.adsb.2.g | tee data/1.aussie.adsb.ymml.log

#tail -f data/1.stderr.aussie.adsb.ymml.log data/1.aussie.adsb.ymml.log &
