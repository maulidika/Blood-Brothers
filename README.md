# Blood Brothers 2 Restoration (Godot 4.3)

Offline, playable reconstruction based on the two APKs (v2.5.2.9.2 and v2.5.3.1.0).
Original UI sprites, fonts, music, sound effects and videos are extracted from YOUR copies of the APKs.
Master data (card stats, quests) was server-side in 2015 and is not in the APKs, so `data/*.json` is new,
original content balanced with `tools/sim_battle.py`.
Keep the extracted assets private: they are (c) DeNA and not licensed for redistribution.

## Setup
1. `python3 tools/extract_assets.py <older apk/zip> <newer apk/zip> --out assets/original`
   (needs Pillow and ffmpeg with libvorbis; originals are only read)
2. Open the folder in Godot 4.3+ (first open imports ~1000 sprites).  Press F5 to play.
3. Android: install Android export templates + JDK 17 + Android SDK, set them in Editor Settings,
   then Project > Export > Android > Export Project (`build/bb2_restoration.apk`). Regenerate the
   preset in the UI if your Godot version complains about `export_presets.cfg`.

## Milestone 1 - what is playable
Title (new/continue) - Home - Adventure (5 zones x 6 stages, boss each zone) - animated battle with skills,
buffs, heal, drain, taunt, AGI order, 3-line formation - rewards, rank-ups, familiar drops, gear drops -
Familiar collection, Combine (level up), Evolution, Gear equip/enhance, Sell - Brigade with cost cap -
Forge Pact (copper/silver/gold) - energy regen offline-aware - daily bonus - local autosave.

## Not yet (next milestones)
Opening movie playback, original cutscenes/animation sheets, Arena/Raid boss (offline AI), tutorial,
items/shop, Ally/trade stubs, treasure hunt/board game, more content from `textureJSON` animations.

See `docs/ARCHITECTURE.md`, `docs/BACKEND_READINESS.md`, `docs/ORIGINAL_FINDINGS.md`.

## Part 8 (asset expansion)
Run in order from the project root (set `BB2_UPLOADS` to the folder holding the two original ZIPs):
`python3 tools/part8/stage1_textures.py assets/extracted_v2`, `python3 tools/part8/stage2_layouts.py data/original_extract assets/extracted_v2`,
`tools/part8/stage3_video.sh <folder with opening_*.mp4> assets/extracted_v2/movie`, `python3 tools/part8/stage4_trace.py`, `python3 tools/part8/build_reports.py <out dir>`.
Results are documented in `docs/PART8_REPORT.md` and `docs/ORIGINAL_FINDINGS.md`. `assets/extracted_v2` and `data/original_extract` contain DeNA material: keep private.
