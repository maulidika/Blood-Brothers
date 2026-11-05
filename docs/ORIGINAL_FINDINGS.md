# Findings from the two APKs
- Engine: ngmoco/Mobage **NGCore** (`libnggame.so`, JS VM). Not Unity/Cocos -> assets and logic are JS + PNG sheets.
- Game code: `assets/bootstrap/<hash>/application.js` (9.3 MB in 2.5.2.9.2, 10.8 MB in 2.5.3.1.0), packaged
  with a single-byte XOR (0x55) - read only to recover sprite tables and structure, nothing was bypassed.
- 2.5.3.1.0 adds ~45 classes: Gear system (Gear*, UserGear*), BossGacha battle, Pvp challenge cut-ins, new skills
  (LuckyShot, ProtectCounterDeBuff) and sheets: battle/sheet04, boss_gacha, gear, pact/sheet05, ui/icon/sheet05.
  2.5.2.9.2 has `ui/header/sheet07` that the newer build dropped.
- Sprite atlas table: `exports.textureJSON` (normalised uv per sprite) -> 1,019 sprites recovered
  (`assets/original/atlas_index.json`).
- Audio: 23 BGM (m4a -> ogg), 70 SFX + jingles; logical names (`home`, `battle`, `bossBattle`, `gacha`...) mapped in
  `data/audio_map.json` from the client's `MusicFiles` / `SoundFiles` tables.
- NOT in the APK (downloaded from the Mobage CDN at runtime): card art, maps, enemy art, cutscenes, master data,
  quests, text for most dialogs (`DownloadContent`). These are the main fidelity gaps; they cannot be restored
  from these APKs alone.
- Server-bound: `socialServer app.mobage.com`, `requireMobageLogin`. Not touched or bypassed; replaced by local save.
