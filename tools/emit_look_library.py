#!/usr/bin/env python3
"""Emit look catalog categories, extra looks, and a per-look WGSL library."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALTAR_CAT = {
    "Bottom Glow": "Gradients",
    "Hidden Light": "Light & space",
    "Edge Light": "Glow",
    "Mesh": "Glow",
    "Bar Array": "Arena",
    "Light Threads": "Christmas",
    "Silk Light": "Volumetric",
    "Sky Opening": "Light & space",
    "Arch Opening": "Light & space",
    "Oculus": "Light & space",
    "Gradient Sweep": "Flowing",
    "Ramp Squares": "Ramp & Glass",
    "Glass Ripple": "Ramp & Glass",
    "Glass Stack": "Flowing forms",
    "Hanging Blades": "Light rooms",
    "Static Glass": "Advent",
    "Scan Bands": "Advent",
    "Bloom Bars": "Glow",
    "Light Slab": "Light rooms",
    "Floating Ellipse": "Light rooms",
    "Dot Curtain": "Stage & LED",
    "Burst Fans": "Stage & LED",
    "Halo": "Glow",
    "Long Exposure": "Flowing forms",
    "Portal": "Light & space",
    "Wave Slats": "Stage & LED",
    "Linear Drift": "Gradients",
    "Pillar": "Light & space",
    "Light Field": "Light & space",
    "Flow": "Flowing",
    "Rings": "Shapes",
    "Rays": "Beams",
    "Silk Wave": "Flowing",
    "Arc": "Shapes",
    "Point Wave": "Shapes",
    "Dot Globe": "Shapes",
    "Halo Ring": "Glow",
    "Eclipse": "Glow",
    "Scan Beam": "Beams",
    "Glitter": "Glow",
    "Streaks": "Beams",
    "Echo": "Glow",
    "Plasma": "Flowing",
    "Threshold": "Light & space",
    "Laser Planes": "Arena",
    "Cross of Rays": "Cross",
    "Silhouette Cross": "Cross",
    "Water Curtain": "Worlds",
    "Caustic Depths": "Volumetric",
    "Snow Glint": "Christmas",
    "Deep Field": "Volumetric",
    "Fog Bank": "Flowing",
    "Corridor": "Light & space",
    "Pool": "Light & space",
    "Moiré": "Lines & grids",
    "Checker Warp": "Lines & grids",
    "Grid Floor": "Lines & grids",
    "Dune Lines": "Lines & grids",
    "Phase Rings": "Shapes",
    "Scan Grid": "Lines & grids",
    "Glass Orb": "Glow",
    "Curved Horizon": "Light & space",
    "Twin Apertures": "Light & space",
    "Ripple Floor": "Scenes",
    "Light Columns": "Light & space",
    "Wire Sphere": "Shapes",
    "Event Horizon": "Worlds",
    "Planet Rise": "Arena",
    "Wire Cube": "Shapes",
    "Halo Bands": "Shapes",
    "Nested Squares": "Shapes",
    "Circuit": "Lines & grids",
    "Light Corridor": "Arena",
    "Failing Ceiling": "Ceiling Lights",
    "Office Ceiling": "Ceiling Lights",
    "Scan Panel": "Advent",
    "Two Inks": "Advent",
    "Smoke Columns": "Advent",
    "Ink Halftone": "Advent",
    "Embers & Snow": "Christmas",
    "Chalk Smear": "Stop Motion",
    "Glass Fins": "Render",
    "Glass Cross": "Cross",
    "Glass Torus": "Render",
    "Arch Rows": "Stage & LED",
    "Block Wall": "Stage & LED",
    "Panel Mosaic": "Stage & LED",
    "Volume Rays": "Volumetric",
    "Hondius · Annunciation": "Advent",
    "Bout · Shepherds": "Advent",
    "Amber Bokeh": "Christmas",
    "Breathing Stars": "Christmas",
    "Curtain Streaks · Cross": "Cross",
}

NEW_LOOKS = [
    ("Gradient Sweep", "Flowing", "{auto:true,controls:[{label:'Swing',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Softness',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Spread',min:0.5,max:3.0,step:0.05,value:1.75, motion: 0.5}]}"),
    ("Light Field", "Light & space", "{auto:true,controls:[{label:'Depth',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Drift',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Brightness',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Flow", "Flowing", "{auto:true,controls:[{label:'Detail',min:0.5,max:2.0,step:0.02,value:1.26, motion: 0.5},{label:'Contrast',min:0.5,max:2.0,step:0.02,value:1.26, motion: 0.5},{label:'Drift',min:0.0,max:2.0,step:0.02,value:1.0, motion: 0.5}]}"),
    ("Silk Wave", "Flowing", "{auto:true,controls:[{label:'Waves',min:1.0,max:4.0,step:0.05,value:2.5, motion: 0.5},{label:'Softness',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Tilt',min:-45.0,max:45.0,step:1.0,value:0.0, motion: 0.5}]}"),
    ("Glitter", "Glow", "{auto:true,controls:[{label:'Density',min:4.0,max:30.0,step:1.0,value:17.0},{label:'Size',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Twinkle',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Echo", "Glow", "{auto:true,controls:[{label:'Rings',min:2.0,max:8.0,step:0.5,value:5.0, motion: 0.5},{label:'Fade',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Center',min:-1.2,max:1.0,step:0.02,value:-0.1, motion: 0.5}]}"),
    ("Plasma", "Flowing", "{auto:true,controls:[{label:'Scale',min:0.5,max:4.0,step:0.1,value:2.3, motion: 0.5},{label:'Swirl',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Contrast',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Threshold", "Light & space", "{auto:true,controls:[{label:'Floor',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Wall',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Horizon',min:-0.8,max:0.6,step:0.02,value:-0.1, motion: 0.5}]}"),
    ("Fog Bank", "Flowing", "{auto:true,controls:[{label:'Height',min:-1.0,max:0.5,step:0.01,value:-0.25, motion: 0.5},{label:'Thickness',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Backlight',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Corridor", "Light & space", "{auto:true,controls:[{label:'Size',min:0.5,max:1.2,step:0.02,value:0.86, motion: 0.5},{label:'Frames',min:3.0,max:10.0,step:1.0,value:7.0},{label:'Glow',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Pool", "Light & space", "{auto:true,controls:[{label:'Size',min:0.3,max:1.2,step:0.02,value:0.76, motion: 0.5},{label:'Softness',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Height',min:-1.0,max:0.0,step:0.02,value:-0.5, motion: 0.5}]}"),
    ("Glass Orb", "Glow", "{auto:true,controls:[{label:'Size',min:0.2,max:1.0,step:0.02,value:0.6, motion: 0.5},{label:'Rim',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Inner light',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Curved Horizon", "Light & space", "{auto:true,controls:[{label:'Curve',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Glow height',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Height',min:-0.8,max:0.5,step:0.02,value:-0.14, motion: 0.5}]}"),
    ("Twin Apertures", "Light & space", "{auto:true,controls:[{label:'Size',min:0.2,max:0.8,step:0.02,value:0.5, motion: 0.5},{label:'Gap',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Glow',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Light Columns", "Light & space", "{auto:true,controls:[{label:'Columns',min:2.0,max:8.0,step:1.0,value:5.0},{label:'Width',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Haze',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5},{label:'Brightness',min:0.2,max:2.0,step:0.05,value:1.1, motion: 0.5},{label:'Pulse',min:0.0,max:1.0,step:0.02,value:0.5, motion: 0.5}]}"),
    ("Hondius · Annunciation", "Advent", "{auto:true,controls:[{label:'Fill',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Drift',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Light',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Warmth',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Flicker',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Soft light',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Canvas',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Bloom',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5}]}"),
    ("Bout · Shepherds", "Advent", "{auto:true,controls:[{label:'Fill',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Drift',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Light',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Warmth',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Flicker',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Soft light',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Canvas',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5},{label:'Bloom',min:0.0,max:1.0,step:0.01,value:0.5, motion: 0.5}]}"),
]

RUST_NEW = [
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.5,3.0,1.75,0.5]],",
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.5,2.0,1.26,0.5],[0.5,2.0,1.26,0.5],[0.0,2.0,1.0,0.5]],",
    "&[[1.0,4.0,2.5,0.5],[0.0,1.0,0.5,0.5],[-45.0,45.0,0.0,0.5]],",
    "&[[4.0,30.0,17.0,0.0],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[2.0,8.0,5.0,0.5],[0.0,1.0,0.5,0.5],[-1.2,1.0,-0.1,0.5]],",
    "&[[0.5,4.0,2.3,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[-0.8,0.6,-0.1,0.5]],",
    "&[[-1.0,0.5,-0.25,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.5,1.2,0.86,0.5],[3.0,10.0,7.0,0.0],[0.0,1.0,0.5,0.5]],",
    "&[[0.3,1.2,0.76,0.5],[0.0,1.0,0.5,0.5],[-1.0,0.0,-0.5,0.5]],",
    "&[[0.2,1.0,0.6,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[-0.8,0.5,-0.14,0.5]],",
    "&[[0.2,0.8,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[2.0,8.0,5.0,0.0],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.2,2.0,1.1,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
    "&[[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5],[0.0,1.0,0.5,0.5]],",
]


def update_looks_ts():
    path = ROOT / "ui" / "looks.ts"
    text = path.read_text()
    text = text.replace('["Curtain Cross","Cross"]', '["Curtain Streaks · Cross","Cross"]')
    for name, cat in ALTAR_CAT.items():
        text = text.replace(f'["{name}","Atmosphere"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Stage"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Glass"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Light Rooms"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Glow"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Cross"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Seasonal"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Geometry"]', f'["{name}","{cat}"]')
        text = text.replace(f'["{name}","Grids"]', f'["{name}","{cat}"]')
    insert = "".join(f'  ["{n}","{c}"],\n' for n, c, _ in NEW_LOOKS)
    text = text.replace("] as const;", insert + "] as const;")
    path.write_text(text)


def update_tune_ts():
    path = ROOT / "ui" / "tune.ts"
    text = path.read_text()
    extra = ",\n".join(spec for _, _, spec in NEW_LOOKS)
    text = text.replace("\n];\nexport const finishTune", ",\n" + extra + "\n];\nexport const finishTune")
    path.write_text(text)


def update_tune_rs():
    path = ROOT / "src" / "tune.rs"
    text = path.read_text()
    needle = "];\npub static FINISH_TUNE"
    extra = "\n".join("    " + row for row in RUST_NEW)
    text = text.replace(needle, extra + "\n];\npub static FINISH_TUNE")
    path.write_text(text)


def main():
    update_looks_ts()
    update_tune_ts()
    update_tune_rs()
    print("catalog and tune tables updated")


if __name__ == "__main__":
    main()
