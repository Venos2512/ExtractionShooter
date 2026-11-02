"""Exports the aliens from Figma into res://assets/<folder> for AlienRig.
Run after editing one in Figma, with Figma open and the bridge plugin running:
    python tools/export_alien.py                     every alien
    python tools/export_alien.py vec_bug_leaper      just that one
Each limb segment, joint and body part becomes one atlas region, placed where it sits
in the component, so the game's rest pose matches the drawing. Writes atlas.png,
atlas_flash.png (white copy for hit flashes) and rig.json. The floor is the bottom of
the component, and the body's center is the part named thorax."""
import json
import os
import re
import sys
import urllib.request

import numpy as np
from PIL import Image

FILE = "unsaved-mvvqypdx-saae2bw7"
## Component in Figma to the folder it goes to.
ALIENS = {
    "vec_bug_worker": "alien_base",
    "vec_bug_bomber": "alien_bomber",
    "vec_bug_leaper": "alien_leaper",
    "vec_bug_stalker": "alien_stalker",
    "vec_bug_shieldboss": "alien_charger",
}
SCALE = 2
# The bridge may only write inside its own project.
RAW = "D:/Workflow2DArt/shots/alien_parts"
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
READ = r"""
await figma.loadAllPagesAsync();
const c=figma.root.findOne(n=>n.type==='COMPONENT'&&n.name==='%s');
const m=c.absoluteTransform,ox=m[0][2],oy=m[1][2];
const info=n=>{const b=n.absoluteBoundingBox,t=n.absoluteTransform;return {id:n.id,name:n.name,box:[b.x-ox,b.y-oy,b.width,b.height],
 t:[t[0][0],t[0][1],t[0][2]-ox,t[1][0],t[1][1],t[1][2]-oy],path:n.vectorPaths?n.vectorPaths[0].data:''};};
return {height:c.height,kids:c.children.map(k=>{const e=info(k);if(k.children)e.kids=k.children.map(info);return e;})};
"""


def call(tool, params):
    body = {"tool": tool, "fileKey": FILE, "params": params}
    req = urllib.request.Request("http://127.0.0.1:1994/rpc", json.dumps(body).encode(), {"Content-Type": "application/json"})
    out = json.load(urllib.request.urlopen(req, timeout=200))
    if out.get("error"):
        raise SystemExit(out["error"])
    return out["data"]


def path_points(node):
    nums = re.findall(r"[MLC]|-?\d+\.?\d*(?:e-?\d+)?", node["path"])
    points, i = [], 0
    while i < len(nums):
        op = nums[i]
        count = 3 if op == "C" else 1
        for k in range(count):
            x, y = float(nums[i + 1 + k * 2]), float(nums[i + 2 + k * 2])
            if k == count - 1:
                a, b, tx, c, d, ty = node["t"]
                points.append((a * x + b * y + tx, c * x + d * y + ty))
        i += 1 + count * 2
    return points


def center(node):
    x, y, w, h = node["box"]
    return (x + w / 2, y + h / 2)


def limb_joints(kids):
    by = {k["name"]: k for k in kids}
    first = path_points(by["seg_1"])
    last = path_points(by["seg_3"])
    hip = ((first[0][0] + first[-1][0]) / 2, (first[0][1] + first[-1][1]) / 2)
    return [hip, center(by["joint_1"]), center(by["joint_2"]), last[1]]


def export(component, folder):
    data = call("run_script", {"code": READ % component})["result"]
    kids = data["kids"]
    raw = f"{RAW}/{folder}"
    out = os.path.join(ASSETS, folder)
    os.makedirs(raw, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    parts, order, limbs, items = {}, [], {}, []
    for k in kids:
        order.append(k["name"])
        nodes = k.get("kids") or [k]
        if k.get("kids"):
            limbs[k["name"]] = {"joints": limb_joints(k["kids"])}
        for n in nodes:
            key = f'{k["name"]}.{n["name"]}' if k.get("kids") else k["name"]
            parts[key] = {"box": n["box"], "file": f"{raw}/{key}.png"}
            items.append({"nodeId": n["id"], "outputPath": parts[key]["file"], "scale": SCALE})
    done = call("save_screenshots", {"items": items})
    if done["failed"]:
        raise SystemExit(done)
    # Shelf-pack with a transparent gutter so linear filtering cannot bleed.
    images = {k: Image.open(p["file"]).convert("RGBA") for k, p in parts.items()}
    width, x, y, row = 512, 2, 2, 0
    for key in sorted(images, key=lambda k: -images[k].height):
        w, h = images[key].size
        if x + w + 2 > width:
            x, y, row = 2, y + row + 2, 0
        parts[key]["region"] = [x, y, w, h]
        x += w + 2
        row = max(row, h)
    atlas = Image.new("RGBA", (width, y + row + 2), (0, 0, 0, 0))
    for key, img in images.items():
        atlas.paste(img, tuple(parts[key]["region"][:2]))
    atlas.save(os.path.join(out, "atlas.png"))
    white = np.asarray(atlas).copy()
    white[:, :, :3] = 255
    Image.fromarray(white).save(os.path.join(out, "atlas_flash.png"))
    rig = {"scale": SCALE, "ground_y": data["height"], "origin": center(next(k for k in kids if k["name"] == "thorax")), "order": order, "limbs": limbs,
           "parts": {k: {"box": p["box"], "region": p["region"]} for k, p in parts.items()}}
    with open(os.path.join(out, "rig.json"), "w", encoding="utf-8") as fh:
        json.dump(rig, fh, indent=1)
    print(component, len(parts), "parts,", atlas.size, "order", order, "origin", rig["origin"])
    for name, limb in limbs.items():
        print(name, [(round(a, 1), round(b, 1)) for a, b in limb["joints"]])


for name in sys.argv[1:] or ALIENS:
    export(name, ALIENS[name])
