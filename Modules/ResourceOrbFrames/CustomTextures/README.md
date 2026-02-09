# ResourceOrbFrames Custom Texture Spec (AI-Ready)

This folder is used when `Resource Orb Frames -> General -> Use Custom Textures` is enabled.

Runtime lookup path:
`BetterUI/Modules/ResourceOrbFrames/CustomTextures`

If custom textures are enabled, BetterUI resolves orb and bar art from this folder.

## 1) Required files (exact names)

- `Bar.dds`
- `Health.dds`
- `MagStam.dds`
- `OrbBorder.dds`
- `OrbFill.dds`
- `OrbOverlay_Shield.dds`
- `OrbSplitter.dds`
- `OrnamentLeft.dds`
- `OrnamentRight.dds`
- `Shield.dds`

## 2) Fast drop-in workflow

1. Generate or paint source images using the exact filenames above (`.png` or `.dds`).
2. Ensure canvas sizes match the table in Section 4 exactly.
3. Convert with profile enforcement:

```powershell
.\tools\ConvertPngToDds.ps1 -InputPath '.\Modules\ResourceOrbFrames\CustomTextures' -Profile ResourceOrbFrames -Format DXT5
```

4. Enable `Use Custom Textures` in Resource Orb Frames settings.
5. Validate both ornament modes:
   `Hide Left Ornament = OFF/ON`
   `Hide Right Ornament = OFF/ON`

## 3) Technical requirements

- File format: DDS
- Recommended compression: `DXT5` / `BC3_UNORM` (matches shipped ROF textures)
- Dimensions: power-of-two
- BC compression rule: dimensions must be multiples of 4
- Alpha: required for most ROF assets

Notes:
- The profile command above enforces exact filename and dimension compatibility for ResourceOrbFrames.
- Missing or invalid files can render as white/blank textures in-game.

## 4) File contract (exact defaults)

| File | Canvas | Shipped Compression | Shipped Mips | Render Role | Key art requirement |
|---|---:|---|---:|---|---|
| `Bar.dds` | 1024x512 | DXT5 | 11 | XP/Cast/Mount frame backdrop | Ornate horizontal frame with transparent center window for fill |
| `OrnamentLeft.dds` | 512x512 | DXT5 | 1 | Left statue/ornament | Keep statue mass centered for center-anchor layout |
| `OrnamentRight.dds` | 512x512 | DXT5 | 1 | Right statue/ornament | Keep statue mass centered for center-anchor layout |
| `OrbBorder.dds` | 512x512 | DXT5 | 1 | Health/Magicka/Stamina border ring | Must include a globe glass-lens look; center must stay transparent enough to reveal `OrbFill.dds` beneath |
| `OrbFill.dds` | 256x256 | DXT5 | 1 | Animated orb fill | Full circular noise/liquid tile; left half feeds Magicka, mirrored right half feeds Stamina |
| `OrbSplitter.dds` | 512x512 | DXT5 | 1 | Magicka/Stamina divider | Vertical divider motif, centered with transparent padding |
| `OrbOverlay_Shield.dds` | 256x256 | DXT5 | 1 | Shield overlay ring fill | Circular shield-energy texture with clean alpha edges |
| `Shield.dds` | 64x64 | DXT5 | 1 | Small shield icon near shield value | Readable at very small size (drawn around 32x32 base) |
| `Health.dds` | 512x512 | DXT5 | 10 | Overlay when left ornament hidden | Decorative health emblem that overlays left orb when ornament hidden |
| `MagStam.dds` | 512x512 | DXT5 | 10 | Overlay when right ornament hidden | Decorative right-side emblem for hidden-ornament mode |

## 5) Runtime size and placement summary

Core scale controls:
- Whole frame scale slider: `0.75 -> 1.75`
- Hidden-ornament orb scale sliders: `1.0 -> 1.2`

Base orb geometry:
- Orb border base diameter: `200`
- Hidden-ornament max border before frame scale: `240`

Bar geometry:
- Bar frame size: `250x150`
- Fill insets: `x=45`, `y=59`
- Usable fill area inside bar: `160x32`

Anchor summary:
- Left ornament: `BgMiddle + (-445, -15)`
- Right ornament: `BgMiddle + (455, -25)`
- Left orb (ornament visible): centered on left ornament + `(50, -10)`
- Left orb (ornament hidden): `BgMiddle + (-395, 25)`
- Right orb (ornament visible): centered on right ornament + `(-60, 5)`
- Right orb (ornament hidden): `BgMiddle + (400, 25)`
- XP bar visible mode: `TOP(left ornament) -> BOTTOM` offset `(0, -99)`
- XP bar hidden-left mode: `CENTER(BgMiddle)` offset `(-350, 108)`
- Mount bar visible mode: `TOP(right ornament) -> BOTTOM` offset `(0, -99)`
- Mount bar hidden-right mode: `CENTER(BgMiddle)` offset `(375, 108)`
- Cast bar: `BOTTOM(back bar) -> TOP` offset `(-30, 45)`

## 6) Element-fit diagrams

Global layout (ornaments visible):

```text
[OrnamentLeft + OrbHealth]      [Back Bar / Front Bar / Quickslot / Companion]      [OrbResource + OrnamentRight]
           |                                      |                                              |
         [XP Bar]                             [Cast Bar]                                    [Mount Bar]
```

Global layout (ornaments hidden):

```text
[OrbHealth + Health.dds overlay] [Back Bar / Front Bar / Quickslot / Companion] [OrbResource + MagStam.dds overlay]
               |                                   |                                           |
             [XP Bar]                           [Cast Bar]                                 [Mount Bar]
```

Left orb layer stack (front to back):

```text
Label text
OrbBorder.dds              (ring + glass-lens styling)
OrbFill.dds (Fog, animated fill)
OrbFill.dds (Fog2, dark base)
```

Shield stack (front to back):

```text
Shield.dds icon
Shield label
OrbOverlay_Shield.dds
```

Right orb layer stack (front to back):

```text
Label text
OrbBorder.dds
OrbSplitter.dds
OrbFill.dds (Magicka left half)
OrbFill.dds (Stamina mirrored right half)
```

## 7) OrbBorder glass-lens requirement (mandatory style rule)

`OrbBorder.dds` must preserve this behavior:
- A visible circular border/rim.
- A globe/glass lens feel inside the ring (subtle highlights/refractions).
- Interior remains transparent enough for `OrbFill.dds` to be clearly visible.

Practical alpha guidance:
- Outer ring/rim: high alpha (near opaque) for silhouette clarity.
- Inner lens effects: partial alpha (semi-transparent highlights/shadows).
- Center area: low alpha or transparent so fill motion is readable.

Avoid:
- Fully opaque center paint that hides the fill texture.
- Hard square edges in the alpha channel.

## 8) AI generation contract (copy into your model prompt)

```json
{
  "target": "ESO BetterUI ResourceOrbFrames custom texture pack",
  "output_format": "DDS",
  "compression": "DXT5/BC3_UNORM",
  "dimension_rules": [
    "power-of-two",
    "multiples of 4"
  ],
  "files": [
    {"name":"Bar.dds","width":1024,"height":512,"role":"ornate horizontal bar frame with transparent center for fill"},
    {"name":"OrnamentLeft.dds","width":512,"height":512,"role":"left ornament statue, centered composition"},
    {"name":"OrnamentRight.dds","width":512,"height":512,"role":"right ornament statue, centered composition"},
    {"name":"OrbBorder.dds","width":512,"height":512,"role":"ring with globe-glass lens interior; center transparent for OrbFill visibility"},
    {"name":"OrbFill.dds","width":256,"height":256,"role":"liquid/noise orb fill tile; works as full, half-left, and mirrored-half-right"},
    {"name":"OrbSplitter.dds","width":512,"height":512,"role":"vertical divider with transparent padding"},
    {"name":"OrbOverlay_Shield.dds","width":256,"height":256,"role":"shield-energy circular overlay"},
    {"name":"Shield.dds","width":64,"height":64,"role":"small readable shield icon"},
    {"name":"Health.dds","width":512,"height":512,"role":"left hidden-ornament overlay emblem"},
    {"name":"MagStam.dds","width":512,"height":512,"role":"right hidden-ornament overlay emblem"}
  ],
  "alpha_rules": [
    "clean transparency edges",
    "no opaque fill-blocking center on OrbBorder"
  ]
}
```

## 9) Recommended AI art prompt template

```text
Create a cohesive fantasy ARPG UI texture pack for ESO BetterUI ResourceOrbFrames.
Keep all assets centered and alpha-clean.
Style: [YOUR STYLE HERE].
Do not add text or logos.
Maintain transparent backgrounds where needed.
Critical rule: OrbBorder must have a glass-lens interior look, but the center must remain transparent enough for animated OrbFill to show through.
Generate these exact files and sizes:
Bar 1024x512, OrnamentLeft 512x512, OrnamentRight 512x512, OrbBorder 512x512,
OrbFill 256x256, OrbSplitter 512x512, OrbOverlay_Shield 256x256, Shield 64x64,
Health 512x512, MagStam 512x512.
```

## 10) Source references

- BetterUI runtime and layout code:
  `Modules/ResourceOrbFrames/Core/OrbVisuals.lua`
  `Modules/ResourceOrbFrames/Core/OrbBars.lua`
  `Modules/ResourceOrbFrames/Constants.lua`
  `Modules/ResourceOrbFrames/Module.lua`
- Conversion tooling:
  `tools/ConvertPngToDds.ps1`
- DDS reference guidance:
  https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-block-compression
  https://www.esoui.com/forums/archive/index.php/t-5323.html
  https://www.esoui.com/forums/archive/index.php/t-6763.html