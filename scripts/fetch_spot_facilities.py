#!/usr/bin/env python3
"""Fills in dog park facilities from OpenStreetMap features mapped inside each park.

Most dog parks in OSM only say "dog park". Volunteers often map the drinking fountain,
trash can, fence or trees as separate features, though. This finds those inside (or within
a few meters of) each bundled dog park and sets the matching facility bits.

Two steps, so a slow download can stop and resume:
  python3 -I scripts/fetch_spot_facilities.py download   # one file per state in scripts/.osm-cache/
  python3 -I scripts/fetch_spot_facilities.py apply      # updates spots_us.json / spots_tw.json

Run download again to continue; finished regions are skipped. To go twice as fast, run a second
copy at the same time with `download reverse`. If a run was killed, delete leftover .part files first.
"""
import json
import math
import os
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPOTS = ROOT / "Leash" / "Resources" / "Spots"
CACHE = pathlib.Path(__file__).resolve().parent / ".osm-cache"
# Another public Overpass server can be set with OVERPASS_URL, e.g. for the second copy.
SERVER = os.environ.get("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
PREFIX = {"node": "n", "way": "w", "relation": "r"}
STATES = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS",
          "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC",
          "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
# ISO 3166 area codes: US states, then Taiwan, Puerto Rico and Guam.
REGIONS = [("ISO3166-2", "US-" + s) for s in STATES] + [("ISO3166-1", c) for c in ("TW", "PR", "GU")]

# Bit positions match Spot.Tag in Spot.swift.
FENCE, WATER, BAG, SHADE = 0, 2, 4, 5
NEAR = 20  # Meters outside the park outline that still count (fences are drawn on the outline).


def query(key, code):
    return f"""[out:json][timeout:900];
area["{key}"="{code}"]->.a;
nwr["leisure"="dog_park"](area.a)->.dp;
.dp out tags geom;
(node(around.dp:{NEAR})["amenity"~"^(drinking_water|waste_basket|shelter|dog_toilet)$"];
 node(around.dp:{NEAR})["vending"="excrement_bags"];
 node(around.dp:{NEAR})["natural"="tree"];
 way(around.dp:{NEAR})["barrier"="fence"];
 way(around.dp:{NEAR})["natural"="wood"];);
out tags center;"""


def download(reverse=False):
    CACHE.mkdir(exist_ok=True)
    todo = [(k, c) for k, c in REGIONS if not (CACHE / f"{c}.json").exists()]
    # Overpass allows two queries at a time: run a second copy with "reverse" to meet in the middle.
    if reverse:
        todo.reverse()
    print(f"{len(REGIONS) - len(todo)} of {len(REGIONS)} regions already downloaded", flush=True)
    for index, (key, code) in enumerate(todo, 1):
        if (CACHE / f"{code}.json").exists() or (CACHE / f"{code}.json.part").exists():
            continue  # Done, or being downloaded by the other copy.
        (CACHE / f"{code}.json.part").touch()
        for attempt in range(5):
            # curl, so it works without Python's own certificate setup.
            run = subprocess.run(
                ["curl", "-sS", "-f", "-m", "960", "-A", "Leash-app-data/1.0",
                 SERVER, "--data-urlencode", "data=" + query(key, code)],
                capture_output=True)
            if run.returncode == 0:
                (CACHE / f"{code}.json.part").write_bytes(run.stdout)
                (CACHE / f"{code}.json.part").rename(CACHE / f"{code}.json")
                print(f"[{index}/{len(todo)}] {code}: {len(json.loads(run.stdout)['elements'])} elements", flush=True)
                break
            print(f"{code}: attempt {attempt + 1} failed ({run.stderr.decode().strip()}), retrying", flush=True)
            time.sleep(30 * (attempt + 1))
        else:
            (CACHE / f"{code}.json.part").unlink(missing_ok=True)
            sys.exit(f"Couldn't download {code}; run again later to continue")
        time.sleep(3)  # Be gentle with the shared Overpass server.
    print("download done", flush=True)


def outline(element):
    if element["type"] == "way":
        return [[(p["lat"], p["lon"]) for p in element.get("geometry", [])]]
    if element["type"] == "relation":
        return [[(p["lat"], p["lon"]) for p in m["geometry"]]
                for m in element.get("members", []) if m.get("role") == "outer" and m.get("geometry")]
    return [[(element["lat"], element["lon"])]]  # A park mapped as a single point.


def is_near(point, rings):
    lat, lon = point
    inside = False
    for ring in rings:
        for i in range(len(ring)):
            (y1, x1), (y2, x2) = ring[i], ring[i - 1]
            if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
                inside = not inside
    if inside:
        return True
    k = 111_320
    kx = k * math.cos(math.radians(lat))
    return any(math.hypot((a - lat) * k, (b - lon) * kx) < NEAR for ring in rings for a, b in ring)


def facilities(park, features):
    tags = park.get("tags", {})
    bits = 0
    if tags.get("barrier") == "fence" or tags.get("fenced") == "yes":
        bits |= 1 << FENCE
    rings = [r for r in outline(park) if r]
    if not rings:
        return bits
    lat0, lon0 = rings[0][0]
    for feature in features:
        point = (feature["lat"], feature["lon"]) if "lat" in feature else (feature["center"]["lat"], feature["center"]["lon"])
        if abs(point[0] - lat0) > 0.02 or abs(point[1] - lon0) > 0.02 or not is_near(point, rings):
            continue
        t = feature.get("tags", {})
        amenity = t.get("amenity")
        if amenity == "drinking_water":
            bits |= 1 << WATER
        if amenity in ("waste_basket", "dog_toilet") or t.get("vending") == "excrement_bags":
            bits |= 1 << BAG
        if t.get("barrier") == "fence":
            bits |= 1 << FENCE
        if t.get("natural") in ("tree", "wood") or amenity == "shelter":
            bits |= 1 << SHADE
    return bits


def apply():
    found = {}
    for _, code in REGIONS:
        path = CACHE / f"{code}.json"
        if not path.exists():
            sys.exit(f"{code} not downloaded yet; run download first")
        elements = json.loads(path.read_text())["elements"]
        parks = [e for e in elements if e.get("tags", {}).get("leisure") == "dog_park"]
        features = [e for e in elements if e.get("tags", {}).get("leisure") != "dog_park"]
        for park in parks:
            bits = facilities(park, features)
            if bits:
                key = PREFIX[park["type"]] + str(park["id"])
                found[key] = found.get(key, 0) | bits
    for name in ("spots_us.json", "spots_tw.json"):
        path = SPOTS / name
        rows = json.loads(path.read_text())
        changed = 0
        for row in rows:
            extra = found.get(row[0], 0)
            if extra & ~row[4]:
                row[4] |= extra
                changed += 1
        # Same compact one-line layout as the bundled files.
        path.write_text(json.dumps(rows, ensure_ascii=False, separators=(",", ":")))
        print(f"{name}: added facilities to {changed} of {len(rows)} parks")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "download":
        download(reverse="reverse" in sys.argv[2:])
    elif command == "apply":
        apply()
    else:
        sys.exit(__doc__)
