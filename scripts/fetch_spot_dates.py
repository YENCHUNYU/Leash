#!/usr/bin/env python3
"""Fetches when each bundled dog park was last edited on OpenStreetMap.

Writes Leash/Resources/Spots/spots_edited.json:
  {"fetched": "<OSM data time>", "edited": {"w123": "2024-03-12", ...}}
Only parks already in spots_tw.json / spots_us.json are kept.

Usage: python3 -I scripts/fetch_spot_dates.py
"""
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Leash" / "Resources" / "Spots"
COUNTRIES = ["TW", "US", "PR", "GU"]
PREFIX = {"node": "n", "way": "w", "relation": "r"}


def fetch(code):
    query = f"""[out:json][timeout:180];
area["ISO3166-1"="{code}"]->.a;
nwr["leisure"="dog_park"](area.a);
convert park ::id=id(), kind=type(), edited=timestamp();
out;"""
    for attempt in range(4):
        # curl, so it works without Python's own certificate setup.
        run = subprocess.run(
            ["curl", "-sS", "-f", "-m", "300", "-A", "Leash-app-data/1.0",
             "https://overpass-api.de/api/interpreter", "--data-urlencode", "data=" + query],
            capture_output=True,
        )
        if run.returncode == 0:
            return json.loads(run.stdout)
        print(f"{code}: attempt {attempt + 1} failed ({run.stderr.decode().strip()}), retrying")
        time.sleep(20 * (attempt + 1))
    raise SystemExit(f"Couldn't fetch {code}")


ids = {row[0] for name in ("spots_tw.json", "spots_us.json") for row in json.loads((ROOT / name).read_text())}
edited, fetched = {}, []
for code in COUNTRIES:
    result = fetch(code)
    fetched.append(result["osm3s"]["timestamp_osm_base"])
    for element in result["elements"]:
        key = PREFIX[element["tags"]["kind"]] + str(element["id"])
        if key in ids:
            edited[key] = element["tags"]["edited"][:10]
    print(f"{code}: {len(result['elements'])} parks")

output = {"fetched": min(fetched), "edited": dict(sorted(edited.items()))}
(ROOT / "spots_edited.json").write_text(json.dumps(output, separators=(",", ":")))
print(f"{len(edited)} of {len(ids)} bundled parks dated; OSM data as of {output['fetched']}")
