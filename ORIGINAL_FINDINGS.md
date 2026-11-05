# Findings from the two APKs (updated in Part 8)

Sources: `Blood_Brothers-2_5_2_9_2.zip` (APK 2.5.2.9.2, March 2015) and `blood-brothers-2-5-3-1-0.zip` (APK 2.5.3.1.0, May 2015).
Originals are only read. Every number below is reproducible with `tools/part8/*.py`; evidence files are listed in `docs/PART8_REPORT.md`.

## Engine and packaging
- Engine: ngmoco/Mobage **NGCore** (`libnggame.so` + JS VM), game code in `assets/bootstrap/<hash>/application.js`
  (9.3 MB in A, 10.8 MB in B), stored with a single-byte XOR (0x55). It is decoded **in memory only** to read tables and structure;
  the file in the APK is never modified. Not an authentication/licence mechanism.
- `webgame.ngmanifest` declares 706 (A) / 720 (B) files; all of them exist in the APK with matching size and MD5.

## Where the client loads assets from (rules read from the code, not guessed)
| Rule | Location in code | Result |
|---|---|---|
| Untagged image path | `BBSPSprite.setImage` -> `BasePath.modifyImagePath` | `Content/lang/images/<path>` (inside the APK) |
| Tagged path `[DOWNLOAD_CONTENT]/…` | `BBUtil.isDownloadableImage`, `modifyImagePath` | `Config.assetHost` (server) |
| Sprite table | `SPTextureManager._getTextureInfo` | `textureJSON[dir][name]` -> sheet + uv; if absent the path is used as a literal file |
| Card art (figure/face/boss) | `PreDownloader`, `BasePath.getFigurePath` | `DownloadContent/common/card/…` (server) |
| Items, gear, region maps, zone maps, zone map data, boost icons, arena backgrounds, board game / treasure hunt / gacha banners | `BasePath.getItemPath/getGearPath/getRegionMapPath/getZoneLoDPath/getMapDataPath/getBoostIconPath/getArenaBackgroundPath/getBoardGame*/getTreasureHunt*/getGachaBannerPath` | `DownloadContent/common/…` or `DownloadContent/lang/…` (server) |
| Battle backgrounds | `BattleBackground.setImage`, `PreDownloader` category `battle_bg` | `Config.assetHost + "/" + DownloadContent/common/ + path` (server) |
| Downloadable AB animations | `settingJSON.settings.abs`, `ABJSON.Downloadables` | 8 animations whose sheets come from `DownloadContent/en/ab/…` |
| Fonts | `BBSPFontManager` preset `en` | default = `trb.ttf` (20), bold = `lt.ttf` |

## What the APKs contain (extracted)
- 1,019 sprites from the sprite table (Part 1), **plus Part 8**: 88 standalone textures (176 files with `_low`), 4 sheets not covered by the
  table (`common/signup/sheet03`, `common/ui/header/sheet01`, partly `common/ui/dialog/sheet01`, `common/login/sheet03`),
  the `imagefont` bitmap fonts (6 styles/sizes, 96 glyphs each hi/low set), 195 UI layouts, 16 animations + 1 download list, 2 videos (converted).
- Audio: 23 BGM + 70 SFX/jingles (native OGG for SFX; M4A BGM converted to OGG).
- APK 2.5.2.9.2 embeds **1** layout and **0** animations; APK 2.5.3.1.0 embeds 195 layouts and 17 `ABJSON` entries (so layout/animation data is only available from B).

## What the APKs do NOT contain (proved by code)
Card art (figure/face/boss), items, gear images, region and zone maps, map data JSON, battle and arena backgrounds, banners, the
`DownloadContent/…` sheets for the 8 downloadable animations, and the master data (cards, skills, quests, rates). These are fetched from the game server.
Because enemies are cards (`figure`/`boss` categories), enemy art is server-side too.

## What the APKs DO contain and was previously thought missing
- The original world map `common/world/worldmap.png` and the region-select UI (layout `RegionSelect`) — now used as the Adventure backdrop.
- Layout and animation data (Part 8) and the `imagefont` bitmap fonts (damage numbers use style `blackframe`).

## Open items
- 56 PNG references are still unresolved: the client expects a local file that is not bundled in either APK and nothing marks it as server content
  (event assets such as Halloween/Pumpkin cut-ins, `easylogin/*`, `Effect41/42` textures, …). They are **not** concluded to be missing; see
  `data/original_extract/reference_trace.csv` (rule, evidence and candidates for each).
- `configuration.bin` (130 bytes, custom binary) is not decoded.
- Embedded API credentials exist in the client configuration. They are deliberately not recorded or used; the project never contacts any server.
