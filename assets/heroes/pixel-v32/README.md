# Hero pixel art v32

Six built-in ImageGen style edits preserve the approved 30 hero identities and
120 skill motifs. The generated PNGs are copied intact. `hero-visual-data.gd`
contains export-safe AtlasTexture metadata; portraits retain the approved UI
framing and icon tile bounds were measured again against the new sources.

`generation-prompts.json` records the exact prompts and reference images.
`hero-art-manifest.json` records source paths, SHA-256 values and mappings.
No hero names, skill IDs, effects, cooldowns or balance values are changed.

The battlefield has one new four-pose Kairen sheet under
`assets/sprites/pixel-v32/`. The other 29 heroes retain their existing animation
sources. Kairen has idle, two walk strides and cast poses in a single right
three-quarter view, mirrored for leftward travel. This is not a new full
four-direction animation set for all 30 heroes.

`PixelArtPipeline.actor_material()` adds restrained channel quantization,
contrast and source-aligned checker dithering. It never resamples atlas UVs or
changes dimensions, feet, animation timing or source alpha by default.
Optional `alpha_cutoff` is used only by monster-specific material copies;
the hero material keeps it at zero. Node tint and fades are applied once.
