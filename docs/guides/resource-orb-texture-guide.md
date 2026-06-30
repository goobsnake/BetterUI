# ResourceOrbFrames Texture Notes

This document describes how to author/refresh the shipped ResourceOrbFrames textures.

Runtime lookup path:
`BetterUI/Modules/ResourceOrbFrames/Textures`

BetterUI always resolves orb and bar art from this folder.

## 1) Required files (exact names)

- `Bar.dds`
- `CastBar.dds`
- `MountBar.dds`
- `OrbBorder.dds`
- `OrbFill.dds`
- `OrbOverlay_Shield.dds`
- `OrbSplitter.dds`
- `OrnamentLeft.dds`
- `OrnamentRight.dds`

## 2) Fast drop-in workflow

1. Generate or paint source images using the exact filenames above (`.png` or `.dds`).
2. Ensure canvas sizes are power-of-two or multiples of 4 (Section 4 lists recommended defaults).
3. Convert with profile enforcement:

```powershell
.\tools\ConvertPngToDds.ps1 -InputPath '.\Modules\ResourceOrbFrames\Textures' -Profile ResourceOrbFrames -Format DXT5
```

4. Reload UI and validate in-game.
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
- The profile command above enforces exact filenames plus dimensions that are power-of-two or multiples of 4 for ResourceOrbFrames.
- Non-default dimensions are allowed and reported as profile notes during conversion.
- If duplicate logical names exist, the converter chooses one source deterministically and warns.
- Missing or invalid files can render as white/blank textures in-game.

## 4) File contract (recommended defaults)

| File | Profile Canvas | Render Role | Key art requirement |
|---|---:|---|---|
| `Bar.dds` | 512x512 | XP/back-bar frame backdrop | Ornate horizontal frame with a COMPLETELY transparent center window; optional glass detail belongs on the surrounding frame only |
| `CastBar.dds` | 512x512 | Cast-bar frame backdrop | Shares the bar-frame visual language; center window must remain transparent for runtime fill |
| `MountBar.dds` | 512x512 | Mount-stamina frame backdrop | Shares the bar-frame visual language; center window must remain transparent for runtime fill |
| `OrnamentLeft.dds` | 512x512 | Left health ornament | Portrait-scale Daedric/demon Elder Scrolls look; red jewels/trinkets; orb socket must match right ornament circumference |
| `OrnamentRight.dds` | 512x512 | Right magicka/stamina ornament | Portrait-scale hero/elven Elder Scrolls look; blue/green jewels/trinkets; orb socket must match left ornament circumference |
| `OrbBorder.dds` | 512x512 | Health/Magicka/Stamina border ring | Must include a globe glass-lens look; center must stay transparent enough to reveal `OrbFill.dds`; rim must still read clearly in ornament-hidden slim mode |
| `OrbFill.dds` | 512x512 | Animated orb fill | Full circular noise/liquid tile; left half feeds Magicka, mirrored right half feeds Stamina |
| `OrbSplitter.dds` | 512x512 | Magicka/Stamina divider | Vertical divider motif, centered with transparent padding |
| `OrbOverlay_Shield.dds` | 512x512 | Shield overlay ring fill | Circular shield-energy texture with clean alpha edges |

The ResourceOrbFrames converter profile currently normalizes every required asset to `512x512`.

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
[OrbHealth] [Back Bar / Front Bar / Quickslot / Companion] [OrbResource]
     |                         |                         |
   [XP Bar]                [Cast Bar]              [Mount Bar]
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

## 8) Per-File Prompt Pack (Self-Contained)

Use each prompt block independently. Each prompt includes its own style rules and file-specific constraints.

Batch consistency recommendations:
- Use one fixed seed for the entire set (if the model supports seeds).
- Keep one reference board/style image set for all files.
- Keep model/render settings constant across all 9 assets.

### `Bar.dds` (512x512)

```text
Create an Elder Scrolls fantasy ARPG UI bar-frame texture.
Canvas: 512x512, transparent background and the graphic is REQUIRED to be centered in the canvas, no art should be outside the canvas or clipped.
Style: painterly-realistic game UI texture art (not photoreal, not flat vector), aged metal/stone filigree, subtle grime, controlled highlights, top-left key light.
Design: ornate horizontal frame with decorative end caps and a center window.
Critical center rule: the middle window must be COMPLETELY transparent so runtime fill is clearly visible; optional glass effects should stay on the surrounding frame, not in the clear window area.
Composition: centered and balanced, with strongest detail on left/right caps and lighter detail near center.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, jewels, trinkets, unrelated symbols.
Avoid: opaque center slabs, heavy fog in center window, cropped frame edges, blur, watermark artifacts, lettering.
```

### `CastBar.dds` (512x512)

```text
Create an Elder Scrolls fantasy ARPG cast-bar frame texture.
Canvas: 512x512, transparent background and the graphic is REQUIRED to be centered in the canvas, no art should be outside the canvas or clipped.
Style: same cohesive painterly-realistic metal/stone filigree family as Bar.dds, but visually tuned for a cast/channel bar.
Design: compact horizontal frame with a transparent center window for runtime cast progress fill.
Critical center rule: the middle window must be COMPLETELY transparent so runtime fill is clearly visible.
Composition: centered and balanced, readable at small cast-bar scale.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, jewels, trinkets, unrelated symbols.
Avoid: opaque center slabs, heavy fog in center window, cropped frame edges, blur, watermark artifacts, lettering.
```

### `MountBar.dds` (512x512)

```text
Create an Elder Scrolls fantasy ARPG mount-stamina bar frame texture.
Canvas: 512x512, transparent background and the graphic is REQUIRED to be centered in the canvas, no art should be outside the canvas or clipped.
Style: same cohesive painterly-realistic metal/stone filigree family as Bar.dds, with subtle motion/stamina identity rather than a separate color theme.
Design: compact horizontal frame with a transparent center window for runtime mount-stamina fill.
Critical center rule: the middle window must be COMPLETELY transparent so runtime fill is clearly visible.
Composition: centered and balanced, readable at small mount-bar scale.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, jewels, trinkets, unrelated symbols.
Avoid: opaque center slabs, heavy fog in center window, cropped frame edges, blur, watermark artifacts, lettering.
```

### `OrnamentLeft.dds` (512x512)

```text
Create a left-side HEALTH ornament texture for ESO BetterUI ResourceOrbFrames.
Canvas: 512x512, transparent background.
Style: Elder Scrolls fantasy ARPG ornament art, painterly-realistic UI texture, aged carved metal/stone, readable medium-scale contrast, top-left key light.
Subject: Daedric or demon-themed portrait/bust figure supporting the orb socket.
Scale rule: portrait/bust scale only, not a giant full-body statue.
Color rule: if jewels/trinkets are present, they must be RED.
Geometry rule: this asset must pair with OrnamentRight using matched visual coverage (same height/width), matched orb socket circumference, and mirrored socket placement.
Socket alignment target: left socket center near (306,246) on a 512x512 canvas.
Composition: centered and balanced for anchor-based placement.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: giant full-body statue silhouettes, asymmetrical off-canvas composition, huge one-sided padding, non-red accent gems/trinkets, text artifacts.
```

### `OrnamentRight.dds` (512x512)

```text
Create a right-side MAGICKA/STAMINA ornament texture for ESO BetterUI ResourceOrbFrames.
Canvas: 512x512, transparent background.
Style: Elder Scrolls fantasy ARPG ornament art, painterly-realistic UI texture, aged carved metal/stone, readable medium-scale contrast, top-left key light.
Subject: hero or elven-themed portrait/bust figure supporting the orb socket.
Scale rule: portrait/bust scale only, not a giant full-body statue.
Color rule: if jewels/trinkets are present, they must be BLUE and/or GREEN.
Geometry rule: this asset must pair with OrnamentLeft using matched visual coverage (same height/width), matched orb socket circumference, and mirrored socket placement.
Socket alignment target: right socket center near (196,261) on a 512x512 canvas.
Composition: centered and balanced for anchor-based placement.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: giant full-body statue silhouettes, style mismatch versus left ornament, non-blue/non-green accent gems/trinkets, off-center framing, text/watermark artifacts.
```

### `OrbBorder.dds` (512x512)

```text
Create a circular orb-border ring texture for ESO BetterUI ResourceOrbFrames.
Canvas: 512x512, transparent background is REQUIRED
Style: Elder Scrolls fantasy ARPG UI ring element, painterly-realistic metallic carved rim with glass-lens interior treatment.
Mandatory visual behavior:
- Thin, crisp circular rim. 
- Subtle inner glass highlights/refractions.
- Center remains transparent/semi-transparent so OrbFill animation is visible underneath.
Dual-fit requirement:
- Ornament ON mode: border aligns behind ornament globe area so ornament framing can visually hide most of the rim.
- Ornament OFF mode: same texture remains a strong standalone rim for slim/basic style.
Composition: perfectly centered and circular.
Alpha quality: smooth anti-aliased transparency. 
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: fully opaque center regions, weak/indistinct rim silhouette, square mask edges, flat plastic look, text artifacts.
```

### `OrbFill.dds` (512x512)

```text
Create an animated-friendly orb fill texture tile for ESO BetterUI ResourceOrbFrames.
Canvas: 512x512.
Style: fantasy ARPG energy texture, painterly-realistic liquid/smoke pattern with smooth gradients and in black and white.
Behavior requirement: must work as full-circle fill and as left-half/right-half mirrored usage without visible directional breakage.
Color behavior: keep texture tint-friendly so runtime red/blue/green colorization remains clear and high-contrast.
Avoid harsh banding and hard seams.
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: hard seams, one-direction stroke patterns that break under mirroring, text artifacts.
```

### `OrbSplitter.dds` (512x512)

```text
Create a centered vertical divider ornament for magicka/stamina split.
Canvas: 512x512, transparent background.
Style: Elder Scrolls fantasy ARPG decorative metal divider with subtle filigree.
Design: thin centered spine-like divider with generous transparent side padding.
Behavior requirement: must remain readable when stretched/scaled by UI runtime.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: thick blocky divider bars, off-center divider placement, opaque full-width backgrounds.
```

### `OrbOverlay_Shield.dds` (512x512)

```text
Create a circular shield-energy overlay texture.
Canvas: 512x512, transparent background.
Style: Elder Scrolls fantasy ARPG magical effect, painterly-realistic glow with controlled highlights.
Design: centered shield ring/glow motif with soft alpha falloff.
Behavior requirement: readable over health orb without hiding underlying orb form.
Alpha quality: smooth anti-aliased transparency with no halo artifacts.
Forbidden: text, logos, watermarks, signatures, UI labels, unrelated symbols.
Avoid: hard-edged opaque disks, square corners, lettering/text artifacts.
```


## 9) AI Batch Instruction Template (All Files)

Use this when your image model supports multi-image output in one request:

```text
Generate a 9-file ESO BetterUI ResourceOrbFrames custom texture set.
Use the per-file prompts exactly as written (they are self-contained and style-locked).
Output these files with exact canvas sizes and transparent backgrounds where required:
Bar (512x512), CastBar (512x512), MountBar (512x512), OrnamentLeft (512x512),
OrnamentRight (512x512), OrbBorder (512x512), OrbFill (512x512), OrbSplitter (512x512),
OrbOverlay_Shield (512x512).
Hard requirements:
- OrbBorder has glass-lens interior + transparent center for OrbFill visibility.
- Bar/CastBar/MountBar center windows are COMPLETELY transparent; optional glass detail is allowed on the surrounding frame only.
- Ornaments are portrait/bust scale (not giant statues), with matched geometry and mirrored socket placement.
- Left ornament = Daedric/demon Elder Scrolls identity with red accents.
- Right ornament = hero/elven Elder Scrolls identity with blue/green accents.
No text, logos, watermark artifacts, or unrelated symbols.
Keep all assets in one cohesive style family.
```

## 10) Source References

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
