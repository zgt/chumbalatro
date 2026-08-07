#!/usr/bin/env bash
# Generate Balatro-style joker art via Codex CLI (gpt-image) and slot it into the Chumbalatro atlas.
#
# Usage:
#   scripts/joker-art.sh [--face] [--no-atlas] <key> <col> <row> "<illustration description>"
#     key        - joker key, used for intermediate filenames (e.g. "butterfly")
#     col, row   - atlas slot (the joker's pos.x / pos.y; for --face, its soul_pos)
#     desc       - what the illustration should depict
#     --face     - generate a floating soul-face bust (transparent background sprite)
#                  instead of a full card face
#     --no-atlas - produce the sprite files but skip compositing into the atlas
#
# Templates (repo root, authoritative):
#   1x_art_template.png / 2x_art_template.png - the base joker card. The JOKER side
#   lettering is extracted from the 1x template and stamped onto every generated card
#   1:1 - the image model never draws it. The template's jester face is the canonical
#   face: any generated character face must reuse its shape and smile (recolors and
#   restyling allowed, like vanilla Perkeo), enforced via reference image + prompt.
#
# Pipeline constraints (.claude/docs/2026-08-06-joker-art-handoff.md): generate large,
# crop to 71:95, nearest-neighbor downscale to 71x95 (the master), nearest-neighbor
# 2x upscale to 142x190. No bilinear/bicubic anywhere.
#
# Produces .claude/art/<key>-{raw,1x,2x}.png. If <key>-raw.png exists, generation is
# skipped and only processing reruns - delete the raw to force a fresh generation.
set -euo pipefail

MODE=card ATLAS_WRITE=1 ARGS=()
for a in "$@"; do
    case "$a" in
        --face) MODE=face ;;
        --no-atlas) ATLAS_WRITE=0 ;;
        *) ARGS+=("$a") ;;
    esac
done
if [[ ${#ARGS[@]} -ne 4 ]]; then
    echo "usage: $0 [--face] [--no-atlas] <key> <col> <row> \"<illustration description>\"" >&2
    exit 1
fi
KEY=${ARGS[0]} COL=${ARGS[1]} ROW=${ARGS[2]} DESC=${ARGS[3]}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART="$ROOT/.claude/art"
mkdir -p "$ART"

TEMPLATE_REF="$ART/template-ref.png"        # 2x template upscaled so the model can read it
FACE_REF="$ART/face-ref.png"                # the template's jester head, upscaled
LETTERS="$ART/letters-overlay-1x.png"       # JOKER side lettering, transparent overlay
ALPHA="$ART/corner-alpha-1x.png"            # rounded-corner mask (from vanilla base joker)
if [[ ! -f "$TEMPLATE_REF" || ! -f "$FACE_REF" || ! -f "$LETTERS" || ! -f "$ALPHA" ]]; then
    magick "$ROOT/2x_art_template.png" -scale 400% "$TEMPLATE_REF"
    # Head-and-face region of the template jester (hat tip to chin).
    magick "$ROOT/2x_art_template.png" -crop 82x96+30+14 +repage -scale 600% "$FACE_REF"
    # Lettering = dark pixels of the 1x template, restricted to the two letter
    # column bands (left JOKER x6-12 y7-50, rotated right JOKER x58-64 y44-87).
    # Split per side, each in the template's dark grey plus an off-white variant
    # for dark backdrops.
    for SIDE in "left:6,7 12,50" "right:58,44 64,87"; do
        NAME=${SIDE%%:*} RECT=${SIDE#*:}
        magick "$ROOT/1x_art_template.png" \( +clone -colorspace gray -threshold 45% -negate \) \
            -alpha off -compose CopyOpacity -composite \
            \( -size 71x95 xc:none -fill white -draw "rectangle $RECT" \) \
            -compose DstIn -composite "$ART/letters-$NAME-dark.png"
        magick "$ART/letters-$NAME-dark.png" -fill '#f2ede2' -colorize 100 "$ART/letters-$NAME-light.png"
        # Each variant gets a 1px outline in the opposite color, laid underneath,
        # so the text stays readable on any backdrop.
        magick "$ART/letters-$NAME-dark.png" \
            \( +clone -channel A -morphology Dilate Disk:1 +channel -fill '#f2ede2' -colorize 100 \) \
            +swap -compose Over -composite "$ART/letters-$NAME-dark.png"
        magick "$ART/letters-$NAME-light.png" \
            \( +clone -channel A -morphology Dilate Disk:1 +channel -fill '#4a4d52' -colorize 100 \) \
            +swap -compose Over -composite "$ART/letters-$NAME-light.png"
    done
    magick "$ART/letters-left-dark.png" "$ART/letters-right-dark.png" -compose Over -composite "$LETTERS"
    magick "$ROOT/balatro-src/resources/textures/1x/Jokers.png" -crop 71x95+0+0 +repage -alpha extract "$ALPHA"
fi

RAW="$ART/$KEY-raw.png"
if [[ ! -f "$RAW" ]]; then
    if [[ "$MODE" == card ]]; then
        PROMPT="Use your image generation tool to generate ONE image and save it to $RAW (exact path).

Subject: a Balatro-style pixel-art joker playing card face. The FIRST attached image is the card template: match its exact card shape, off-white face, subtle rounded border, chunky pixel art style, thick very-dark-warm-gray outlines, saturated flat colors with simple 2-tone cel shading. Replace the template's central jester with the illustration described below, and give the card a loud saturated patterned backdrop that fills the face without fighting the subject.

IMPORTANT: do NOT draw any text or lettering anywhere - the template's JOKER side text is stamped on afterwards mechanically, so the side margins must stay clean backdrop.

IMPORTANT: if the illustration includes a character with a face, base the face on the SECOND attached image (the base joker's face): same face shape, same wide smile, same eye style - restyle colors, hair, headwear and accessories to fit the character (the way Balatro's Perkeo reuses the base joker face with different colors).

Central illustration: $DESC

Portrait orientation, 1024x1536 or similar portrait size. After generating, verify with ls that $RAW exists."
    else
        PROMPT="Use your image generation tool to generate ONE image and save it to $RAW (exact path).

Subject: a single floating pixel-art character bust (head and shoulders only, NOT a card): the described character below. The attached image is the base joker's face from Balatro - the generated face MUST reuse its exact face shape, wide smile and eye style, restyled in colors, hair, headwear and accessories to fit the character (the way Balatro's legendary jokers reuse the base face with different styling). Chunky pixel proportions, thick very-dark outlines, flat saturated colors, minimal shading.

Character: $DESC

Background: solid pure white (#FFFFFF), nothing else - no card, no border, no text. After generating, verify with ls that $RAW exists."
    fi
    REFS=(-i "$TEMPLATE_REF" -i "$FACE_REF")
    [[ "$MODE" == face ]] && REFS=(-i "$FACE_REF")
    printf '%s' "$PROMPT" | codex exec --skip-git-repo-check -s workspace-write -m gpt-5.6-sol "${REFS[@]}" - >/dev/null
    [[ -f "$RAW" ]] || { echo "error: codex did not produce $RAW" >&2; exit 1; }
fi

if [[ "$MODE" == card ]]; then
    # Center-crop to 71:95, nearest-neighbor downscale, corner mask, stamp lettering.
    read -r RW RH < <(magick identify -format '%w %h\n' "$RAW")
    CW=$RW CH=$((RW * 95 / 71))
    if [[ $CH -gt $RH ]]; then CH=$RH CW=$((RH * 71 / 95)); fi
    magick "$RAW" -gravity center -crop "${CW}x${CH}+0+0" +repage -sample '71x95!' "$ART/$KEY-1x.png"
    magick "$ART/$KEY-1x.png" "$ALPHA" -alpha off -compose CopyOpacity -composite "$ART/$KEY-1x.png"
    # Stamp the JOKER lettering 1:1; per side, use the off-white variant when the
    # backdrop under the letters is dark.
    for SIDE in "left:7x44+6+7" "right:7x44+58+44"; do
        NAME=${SIDE%%:*} BAND=${SIDE#*:}
        MEAN=$(magick "$ART/$KEY-1x.png" -crop "$BAND" +repage -alpha off -colorspace gray -format '%[fx:mean]' info:)
        VARIANT=dark; awk "BEGIN{exit !($MEAN < 0.5)}" && VARIANT=light
        magick "$ART/$KEY-1x.png" "$ART/letters-$NAME-$VARIANT.png" -compose Over -composite "$ART/$KEY-1x.png"
    done
else
    # Trim the white background, make it transparent, fit the bust into the cell.
    magick "$RAW" -fuzz 8% -trim +repage -bordercolor white -border 8 \
        -fill none -fuzz 10% -draw 'alpha 0,0 floodfill' -sample x62 "$ART/$KEY-bust.png"
    magick -size 71x95 xc:none "$ART/$KEY-bust.png" -gravity North -geometry +0+9 -composite "$ART/$KEY-1x.png"
fi
magick "$ART/$KEY-1x.png" -scale 200% "$ART/$KEY-2x.png"

if [[ "$ATLAS_WRITE" == 1 ]]; then
    # Composite into both atlases, growing the canvas when the slot is new.
    for SCALE in 1 2; do
        ATLAS="$ROOT/assets/${SCALE}x/Chumbalatro.png"
        W=$((71 * SCALE)) H=$((95 * SCALE))
        X=$((COL * W)) Y=$((ROW * H))
        read -r AW AH < <(magick identify -format '%w %h\n' "$ATLAS")
        NEEDW=$((X + W)); [[ $NEEDW -lt $AW ]] && NEEDW=$AW
        NEEDH=$((Y + H)); [[ $NEEDH -lt $AH ]] && NEEDH=$AH
        if [[ $NEEDW -ne $AW || $NEEDH -ne $AH ]]; then
            magick "$ATLAS" -background none -gravity NorthWest -extent "${NEEDW}x${NEEDH}" "$ATLAS"
        fi
        # Punch the slot transparent (Dst_Out only affects the overlap area), then
        # lay the new sprite over it. A plain Src compose would wipe the atlas.
        magick "$ATLAS" \( -size "${W}x${H}" xc:black \) -geometry "+$X+$Y" -compose Dst_Out -composite \
            "$ART/$KEY-${SCALE}x.png" -geometry "+$X+$Y" -compose Over -composite "$ATLAS"
    done
    echo "done: $KEY at atlas pos {x=$COL, y=$ROW}"
    echo "next: deploy with  cp -r Chumbalatro.lua chumbalatro.json assets <Mods dir>/Chumbalatro/"
else
    echo "done (no atlas write): $ART/$KEY-1x.png / $KEY-2x.png"
fi
