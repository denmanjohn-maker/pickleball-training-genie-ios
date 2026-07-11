#!/usr/bin/env python3
"""Regenerates PickleballTrainingGenie/Resources/ZipPrefixCentroids.json.

The app matches a user's zip code to the closest tournament city using a table
of 3-digit zip-prefix centroids derived from the US Census ZCTA Gazetteer.
Re-run this if the Census publishes a new gazetteer (the data changes very
slowly; regeneration is rarely needed).

Usage:
    curl -sL -o /tmp/gaz_zcta.zip \
        'https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2023_Gazetteer/2023_Gaz_zcta_national.zip'
    unzip -o /tmp/gaz_zcta.zip -d /tmp
    python3 scripts/generate_zip_centroids.py /tmp/2023_Gaz_zcta_national.txt
"""
import collections
import json
import pathlib
import sys

if len(sys.argv) != 2:
    sys.exit(__doc__)

gazetteer = sys.argv[1]
out_path = pathlib.Path(__file__).resolve().parent.parent / "PickleballTrainingGenie" / "Resources" / "ZipPrefixCentroids.json"

sums = collections.defaultdict(lambda: [0.0, 0.0, 0])
with open(gazetteer) as f:
    next(f)  # header
    for line in f:
        parts = line.split("\t")
        zcta = parts[0].strip()
        lat, lon = float(parts[5]), float(parts[6])
        s = sums[zcta[:3]]
        s[0] += lat
        s[1] += lon
        s[2] += 1

centroids = {p: [round(s[0] / s[2], 4), round(s[1] / s[2], 4)] for p, s in sorted(sums.items())}
out_path.write_text(json.dumps(centroids, separators=(",", ":")))
print(f"Wrote {len(centroids)} prefixes to {out_path}")
