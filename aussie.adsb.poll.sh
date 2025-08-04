#!/bin/bash
set -euo pipefail

./aussie.adsb.2.g >> data/1.aussie.adsb.ymml.log 2>> data/1.stderr.aussie.adsb.ymml.log &

tail -f data/1.stderr.aussie.adsb.ymml.log data/1.aussie.adsb.ymml.log &

sleep 1
pstree -p -g -T -a 243799
ps -o pgrp= $$

wait

# kill with `pkill -g $(ps -o pgrp= $(jobs -p))` if there is only one job.
