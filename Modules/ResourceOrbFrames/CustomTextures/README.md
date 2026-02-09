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
| `Bar.dds` | 1024x512 | DXT5 | 11 | XP/Cast/Mount frame backdrop | Ornate horizontal frame with a highly transparent center window (glass allowed) so fill is clearly visible |
| `OrnamentLeft.dds` | 512x512 | DXT5 | 1 | Left health ornament | Portrait-scale Daedric/demon Elder Scrolls look; red jewels/trinkets; orb socket must match right ornament circumference |
| `OrnamentRight.dds` | 512x512 | DXT5 | 1 | Right magicka/stamina ornament | Portrait-scale hero/elven Elder Scrolls look; blue/green jewels/trinkets; orb socket must match left ornament circumference |
| `OrbBorder.dds` | 512x512 | DXT5 | 1 | Health/Magicka/Stamina border ring | Must include a globe glass-lens look; center must stay transparent enough to reveal `OrbFill.dds`; rim must still read clearly in ornament-hidden slim mode |
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
[Portrait OrnamentLeft + OrbHealth] [Back Bar / Front Bar / Quickslot / Companion] [OrbResource + Portrait OrnamentRight]
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
- Must align with ornament globe sockets so rim can be visually tucked behind ornament framing when ornaments are shown.
- Must still read as a strong standalone ring when ornaments are hidden (slim/basic mode).

Practical alpha guidance:
- Outer ring/rim: high alpha (near opaque) for silhouette clarity.
- Inner lens effects: partial alpha (semi-transparent highlights/shadows).
- Center area: low alpha or transparent so fill motion is readable.

Avoid:
- Fully opaque center paint that hides the fill texture.
- Hard square edges in the alpha channel.

## 8) Style Lock Contract (paste this into every generation request)

Use this as the shared art direction for all 10 files so results stay consistent:

```text
STYLE LOCK (APPLY TO ALL FILES)
- Theme: Elder Scrolls fantasy ARPG UI, hand-crafted metal/stone ornament style.
- Rendering: painterly-realistic game UI texture art, not photoreal, not flat vector.
- Materials: aged metal, carved filigree, subtle grime, controlled specular highlights.
- Lighting: top-left key light, soft fill, readable contrast at small sizes.
- Composition: centered subject, balanced silhouette, no cropped important details.
- Ornament scale rule: ornaments should read as portrait/bust scale figures holding an orb, not giant full-body statues.
- Ornament pair geometry rule: left/right ornaments must share the same canvas coverage, same visual height/width, same orb socket circumference, and mirrored orb socket placement.
- Ornament socket alignment target (512x512 canvas): left socket center near (306,246), right socket center near (196,261), using equal socket diameter.
- Color discipline: strong red/blue/green readability for orb states; neutral ornament metals.
- Alpha discipline: smooth edge anti-aliasing, no hard matte halos, no checker artifacts.
- Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
- Cohesion rule: all assets must look from the same set/artist and same era.
- Critical ROF rules:
  - OrbBorder must keep a glass-lens interior look with transparent center so OrbFill remains visible underneath.
  - Bar center window must be highly transparent (glass tint allowed) so runtime bar fill is easy to read.
```

Batch consistency recommendations:
- Use one fixed seed for the entire set (if the model supports seeds).
- Keep one reference board/style image set for all files.
- Do not change style terms between files; only change file-specific geometry instructions.

## 9) Per-File Prompt Pack (one prompt per file)

Use each block independently. Keep the Style Lock text above prepended to each prompt.

### `Bar.dds` (1024x512)

```text
Create a transparent-background fantasy UI bar frame texture.
Canvas: 1024x512.
Design: ornate horizontal frame with decorative end caps and a clear center window.
The center window must be HIGHLY transparent and readable for runtime fill (about 160x32 equivalent); subtle glass look is allowed but do not obscure fill visibility.
Keep details strongest on left/right caps, lighter detail near center.
No text. No icons. No logos.
```

Negative prompt:
```text
No opaque center slab, no heavy fog in center window, no cropped frame edges, no blur, no watermark, no lettering.
```

### `OrnamentLeft.dds` (512x512)

```text
Create a left-side ornament texture for the HEALTH orb.
Canvas: 512x512, transparent background.
Subject: Elder Scrolls Daedric/demon-themed portrait or bust figure holding/supporting the orb area.
Do not make it a giant full-body statue; keep it portrait-scale.
If jewels/trinkets are present, they must be RED.
Match right ornament geometry: same visual height/width coverage and same orb socket circumference.
Use mirrored socket placement pair logic: left socket should mirror the right-side ornament socket arrangement.
Composition must be centered and balanced for anchor-based layout.
Preserve readable silhouette at medium scale.
No text or symbols that imply words.
```

Negative prompt:
```text
No giant full-body statue silhouette, no asymmetrical off-canvas composition, no huge empty padding on one side, no non-red accent gems, no text.
```

### `OrnamentRight.dds` (512x512)

```text
Create a right-side ornament texture for the MAGICKA/STAMINA orb.
Canvas: 512x512, transparent background.
Subject: Elder Scrolls hero or elven-themed portrait or bust figure holding/supporting the orb area.
Do not make it a giant full-body statue; keep it portrait-scale.
If jewels/trinkets are present, they must be BLUE and/or GREEN.
Must visually pair with OrnamentLeft and match its geometry: same visual height/width coverage and same orb socket circumference.
Use mirrored socket placement pair logic relative to OrnamentLeft.
Composition centered for center anchoring; keep orb-holding region visually open and readable.
No text or logos.
```

Negative prompt:
```text
No giant full-body statue silhouette, no mismatched style versus left ornament, no non-blue/non-green accent gems, no off-center framing, no text/watermarks.
```

### `OrbBorder.dds` (512x512)

```text
Create a circular orb border ring texture with a glass-lens interior look.
Canvas: 512x512, transparent background.
Mandatory: strong border rim + subtle inner glass highlights/refractions.
Mandatory: center area must remain transparent/semi-transparent so underlying OrbFill animation is visible.
Fit behavior requirement:
- When ornaments are visible, this border should align behind the ornament globe area so ornament framing can visually hide most of the rim.
- When ornaments are hidden, the same file must still read as a strong standalone rim for slim/basic style.
Keep border circular and centered.
No text or symbols.
```

Negative prompt:
```text
No fully opaque center, no weak/indistinct rim, no square mask edges, no flat plastic look, no text.
```

### `OrbFill.dds` (256x256)

```text
Create an animated-friendly orb fill texture tile.
Canvas: 256x256.
Design: organic liquid/smoke energy pattern with smooth gradients and no harsh banding.
Must work as full-circle fill and as left-half/right-half mirrored usage.
Keep center readable and avoid directional artifacts that break when mirrored.
Background should support transparency where appropriate.
```

Negative prompt:
```text
No hard seams, no obvious one-direction strokes that look wrong when mirrored, no text.
```

### `OrbSplitter.dds` (512x512)

```text
Create a centered vertical divider ornament for splitting magicka/stamina.
Canvas: 512x512, transparent background.
Design: thin decorative spine/filigree line centered vertically.
Keep plenty of transparent side padding; divider must remain readable when stretched.
No text.
```

Negative prompt:
```text
No thick blocky bar, no off-center divider, no opaque full-width background.
```

### `OrbOverlay_Shield.dds` (256x256)

```text
Create a circular shield-energy overlay texture.
Canvas: 256x256, transparent background.
Design: magical shield ring/glow pattern, centered, with soft falloff alpha.
Readable over health orb without hiding underlying shape completely.
No symbols or text.
```

Negative prompt:
```text
No hard-edged opaque disk, no square corners, no lettering.
```

### `Shield.dds` (64x64)

```text
Create a tiny shield icon for UI display.
Canvas: 64x64, transparent background.
Design: clean fantasy shield glyph/icon with high readability at 32x32 equivalent.
Strong silhouette, minimal noise.
No text.
```

Negative prompt:
```text
No tiny unreadable micro-detail, no low-contrast muddy icon, no text.
```

### `Health.dds` (512x512)

```text
Create a left orb overlay emblem used when the left ornament is hidden.
Canvas: 512x512, transparent background.
Design: decorative circular health-themed motif (subtle runes/filigree allowed, no text characters).
Must center on orb and not block value readability.
```

Negative prompt:
```text
No opaque center plate, no busy noise over text center, no literal typography.
```

### `MagStam.dds` (512x512)

```text
Create a right orb overlay emblem used when the right ornament is hidden.
Canvas: 512x512, transparent background.
Design: decorative motif that complements split blue/green orb usage and matches Health overlay style.
Centered composition, moderate detail, preserve readability for numbers.
```

Negative prompt:
```text
No opaque central blocking layer, no mismatched art style, no text.
```

## 10) AI batch instruction template (all files)

Use this to request the full set from a model that supports multi-image generation:

```text
Generate a 10-file ESO BetterUI ResourceOrbFrames custom texture set.
Follow the provided Style Lock exactly.
Output these files with exact canvas sizes and transparent backgrounds where required:
Bar (1024x512), OrnamentLeft (512x512), OrnamentRight (512x512), OrbBorder (512x512),
OrbFill (256x256), OrbSplitter (512x512), OrbOverlay_Shield (256x256), Shield (64x64),
Health (512x512), MagStam (512x512).
Hard requirement: OrbBorder must have a glass-lens interior and transparent center so OrbFill remains visible under it.
Hard requirement: Bar center window must be highly transparent (glass tint allowed) so bar fill stays readable.
Hard requirement: ornaments are portrait/bust scale (not giant statues), with matched geometry and mirrored orb sockets.
Hard requirement: left ornament = Daedric/demon Elder Scrolls feel with red accents; right ornament = hero/elven Elder Scrolls feel with blue/green accents.
Do not include text, logos, or watermark artifacts in any file.
Keep all assets in one cohesive style family.
```

## 11) Source references

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
