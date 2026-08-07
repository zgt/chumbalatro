# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Steamodded (SMODS) mod for Balatro that adds custom Jokers. Pure Lua, no build step, no tests — the mod is loaded by the Steamodded mod loader when Balatro launches.

## Install / run

There is no build or test command. To test changes, the mod must be present in Balatro's Mods directory and the game restarted:

- Mods dir (Steam/Proton): `/home/m/.local/share/Steam/steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods/`
- After editing files in this repo, copy the changed files into `<Mods dir>/Chumbalatro/` (deploy = `cp -r Chumbalatro.lua chumbalatro.json assets <Mods dir>/Chumbalatro/`). Do this after every change — the game loads from the Mods dir, not this repo.
- Runtime logs from the lovely injector land in `<Mods dir>/lovely/log/` — check the newest file there for Lua errors after a crash or a joker not loading.
- Installed Steamodded lives at `<Mods dir>/smods/` (its `lsp_def/` and `src/` are the authoritative API reference for the exact installed version).

## Structure

- `chumbalatro.json` — mod manifest (id `CHUMBA`, prefix `chmb`, requires Steamodded >= 1.0.0~ALPHA). `main_file` points at `Chumbalatro.lua`.
- `Chumbalatro.lua` — the entire mod: the sprite atlas, all `SMODS.Joker` definitions, shared helper functions, and vanilla-function hooks. New jokers go in this file.
- `joker_template.lua` — boilerplate skeleton for a new `SMODS.Joker`; copy from it, it is not loaded by the game.
- `assets/1x/` and `assets/2x/Chumbalatro.png` — sprite atlas, 71x95 px per card (2x is double). Joker `pos = {x, y}` indexes into this grid.

## How the code is organized

`Chumbalatro.lua` has three layers, in order:

1. **Joker definitions** (`SMODS.Joker { ... }`). Each has `loc_txt`, `config.extra` (tunable numbers), `loc_vars` (feeds `#1#`-style template vars into the description), and `calculate(self, card, context)` (the effect, gated on context flags like `context.individual`, `context.end_of_round`, `context.cardarea`).
2. **Helpers**: `with_deck_effects`, `multiply_values`, `deep_copy`, `format_number` — used by Snowball to scale a neighboring joker's `ability` table. `multiply_values` deliberately skips non-value keys (`id`, `colour`, nominals, etc.); keep that exclusion list in mind if new ability fields misbehave.
3. **Per-round state**: `SMODS.current_mod.reset_game_globals(run_start)` rerolls the "kissing cards" (two random distinct-rank cards from the deck) at run start and each round. Per-round mod state lives on `G.GAME.current_round.*` so it persists in saves; `loc_vars` must tolerate that state being absent (collection view has no run).

## Designing new jokers

- Check `.claude/docs/vanilla-joker-directory.md` first — a catalogue of all vanilla jokers plus this mod's, with a "covered design niches" section. New jokers must not duplicate an existing idea or theme. Vanilla source for deeper checks is in `balatro-src/` (jokers in `game.lua`, effect text in `localization/en-us.lua`).
- Joker art is generated with `scripts/joker-art.sh [--face] [--no-atlas] <key> <col> <row> "<illustration description>"` — it calls Codex CLI's image generation, nearest-neighbor downscales to 71x95 (1x master, 2x is a pixel-doubled copy), and composites the sprite into both atlases at the given slot. Reruns reuse `.claude/art/<key>-raw.png`; delete it to force a fresh generation. `--face` generates a floating soul-face bust (transparent background) for legendary `soul_pos` slots instead of a card.
- Art authority: `1x_art_template.png` / `2x_art_template.png` in the repo root (the base joker card). The JOKER side lettering is never AI-drawn — the script stamps the template's lettering pixels 1:1 after generation (off-white variant auto-selected on dark backdrops). Any generated character face must reuse the template jester's face shape/smile restyled (the vanilla Perkeo approach); the script enforces this via a face crop of the template passed as a reference image. Remaining constraints live in `.claude/docs/2026-08-06-joker-art-handoff.md`.

## Conventions

- Joker keys are lowercase (`kissing`, `snowball`); Steamodded prefixes them to `j_chmb_<key>` automatically.
- Randomness must go through `pseudorandom`/`pseudorandom_element` with a `pseudoseed('...')` so runs stay seed-deterministic.
- Probability effects use the SMODS probability API (`SMODS.pseudorandom_probability` for the roll, `SMODS.get_probability_vars` in `loc_vars` for display) — never read `G.GAME.probabilities.normal` directly; the API is what makes Oops! All 6s and probability-modifying jokers apply.
- Deferred/animated effects are queued via `G.E_MANAGER:add_event(Event({...}))`; on-card feedback uses `card_eval_status_text` and `juice_up`.
