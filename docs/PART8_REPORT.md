# Laporan Bagian 8 — Ekspansi Ekstraksi dan Rekonstruksi Aset

Basis: audit sebelumnya (`BB2_Asset_Audit.md`, kedua CSV). Semua hasil baru ada di folder terpisah: `assets/extracted_v2/` dan `data/original_extract/`
(tidak menimpa `assets/original/`). APK/ZIP asli hanya dibaca. Tidak ada koneksi ke server, dan kredensial yang tertanam di klien tidak dicatat maupun dipakai.
Skrip yang menghasilkan semuanya: `tools/part8/` (`stage1_textures.py`, `stage2_layouts.py`, `stage3_video.sh`, `stage4_trace.py`, `build_reports.py`).

## Ringkasan
| Tugas | Hasil | Status |
|---|---|---|
| 1. Tekstur mandiri | 88 file (176 dengan varian `_low`), byte-exact | selesai, divalidasi |
| 1. Sheet di luar tabel sprite | 4 sheet (8 file) + 4 region turunan | selesai |
| 1. imagefont | 6 set (3 gaya x hi/low), 96 glyph per set high/low, `.fnt` BMFont + tabel glyph | selesai, glyph divalidasi lewat render |
| 2. Layout UI | 195 JSON | selesai, round-trip lossless |
| 2. Animasi | 16 animasi + 1 daftar unduhan (`Downloadables`) = 17 entri `ABJSON` | selesai |
| 3. Video | 2 MP4 -> Ogg Theora | selesai, ada 1 keterbatasan (lihat 3) |
| 4. Pelacakan referensi | 81 referensi unik ditelusuri | 6 ditemukan, 5 server, 14 bukan file, 56 belum terselesaikan |
| 5. Integrasi Godot | 4 aset asli menggantikan placeholder | selesai, **belum diuji di Godot** |
| 6. Dokumentasi | laporan, `ORIGINAL_FINDINGS.md`, 3 CSV | selesai |

Koreksi atas audit sebelumnya: jumlah tekstur mandiri adalah **88**, bukan 89. `ui/header/sheet07.png` (hanya ada di 2.5.2.9.2) ternyata sudah tercakup tabel sprite dan sempat salah dikelompokkan.
`2.5.2.9.2` hanya menyematkan 1 layout dan 0 animasi, jadi data layout/animasi hanya tersedia utuh dari `2.5.3.1.0`.

## 1. Tekstur, sheet, imagefont
**Tekstur mandiri (88).** Dipilih: PNG di `Content/lang/images/` yang sheet-nya tidak ada di tabel `textureJSON` kedua versi (varian `_low` mengikuti sheet induknya).
86 identik di A dan B, 2 hanya di B (`common/gear/frame/gear_frame_unpaid_m`, `_s`). Struktur folder, nama, resolusi, dan alpha dipertahankan (byte-exact dari entri APK).
Manifest: `assets/extracted_v2/manifest_stage1.csv`, gabungan di `BB2_Part8_extraction_manifest.csv`.

**Validasi.** 196 file dibaca ulang langsung dari APK dan dibandingkan byte-per-byte: 0 selisih. Dimensi, mode warna dan transparansi sama dengan sumber. Contact sheet visual memastikan isinya benar (mis. `common/signup/sheet03.png` = art layar "Select warlord").

**4 sheet di luar tabel.** `common/signup/sheet03.png` (1024x1024) dan `common/ui/header/sheet01.png` (512x512) tidak punya sprite di tabel: seluruh gambar adalah asetnya. `common/ui/dialog/sheet01.png`
dan `common/login/sheet03.png` punya area di luar tabel; masing-masing menghasilkan 1 region turunan (`regions/…/region_00.png`, nama diberikan oleh kami, bukan file asli) selain salinan utuh sheet-nya.

**imagefont.** Format TexturePacker (`%21.png` = karakter `!`). Bug yang ditemukan dan diperbaiki: koordinat JSON memakai ruang `meta.size` 512, sedangkan PNG high = 256 dan low = 128 (kecuali `blackframe` 128/128),
sehingga rect harus diskalakan (`png.lebar / meta.size.w`). Hasil: `blackframe` = `#%*+-.0123456789` (`#` = ikon "LV"), `cutin` = angka besar bergaya kuas, `white` = huruf latin, angka, tanda baca (70 glyph).
Divalidasi dengan render teks (mis. "Damage1234!(+5)").

## 2. Data internal JavaScript
`application.js` (XOR 0x55) di-decode **hanya di memori**; file di APK tidak diubah dan salinan JS yang di-decode tidak disimpan di proyek.
- `data/original_extract/layouts/*.json`: 195 layout (`lbViewJSON`, 876 KB). Tipe node: component 867, text 959, sprite 697, button 267, image 195, view 42, dll. (`_layout_schema.json`).
- `data/original_extract/animations/*.json`: `ABJSON` = format AnimationBuilder (30 fps, layar 320x480). 16 animasi (`CutIn*`, `Treasure2_*`, `Halloween1`, `MysteryEncounter`, `SnowCutIn`, `SnowTest`, `ArenaBossAppear`) + `Downloadables` (daftar 7 URL sheet yang diunduh). Jadi "17 animasi cut-in" sebenarnya 16 animasi + 1 daftar unduhan.
- `_index.json`: per file ukuran, SHA-256, jumlah node per tipe, klasifikasi rujukan gambar, dan apakah ada di APK A.
- Validasi: semua JSON valid ketat (tanpa NaN/Infinity), kedalaman nesting maksimum 18 (batas parser JSON Godot 512), round-trip sama dengan sumber, dan uji kebocoran kredensial pada seluruh file teks proyek: negatif (hanya hasil boolean, nilai tidak ditampilkan).
- Rujukan gambar di layout/animasi (distinct per file): 798 cocok persis tabel sprite, 53 file mandiri di APK, 31 penanda server, 62 tidak terselesaikan (47 nama unik, dibawa ke bagian 4). 181 dari 195 layout sepenuhnya lokal.

## 3. Video
Sumber: `Content/lang/audio/movie/opening_01.mp4` (1.419.972 B) dan `opening_02.mp4` (1.924.291 B), identik di A dan B. H.264 Main, 320x480, 30 fps, yuv420p, **tanpa aliran audio**, jadi tidak ada audio yang perlu dipertahankan.
Format tujuan: **Ogg Theora (.ogv)**, satu-satunya format video yang diputar native oleh Godot 4. Parameter: `-q:v 10` (maksimum), resolusi, fps dan pix_fmt sama, `-fps_mode passthrough`.

| | opening_01.ogv | opening_02.ogv |
|---|---|---|
| Ukuran | 6.280.541 B | 3.874.658 B |
| Frame sumber / frame Theora | 360 / 324 | 410 / 403 |
| SSIM / PSNR rata-rata | 0,9919 / 46,2 dB | 0,9910 / 46,0 dB |
| Decode penuh | tanpa error | tanpa error |

Selisih frame bukan frame hilang: tepat sama dengan frame sumber yang identik dengan frame sebelumnya (36 dan 8 frame). Theora menyandikannya sebagai tahan-frame dan timeline dipertahankan lewat lonjakan pts.
**Keterbatasan:** `opening_01` berakhir ±0,37 detik lebih awal (durasi 11,63 s vs 12,00 s) karena 23 frame terakhirnya statis. Ini tidak dimodifikasi.
Kode asli memutar `opening_01` (11 s) lalu `opening_02` (14 s) di `PrologueScene`/`OpeningMovie`, konsisten dengan hasil konversi.

## 4. Pelacakan referensi PNG (`data/original_extract/reference_trace.csv`)
Cakupan: 74 referensi dari audit B + 1 tambahan hanya di A + 6 hanya dari data layout/animasi = **81 referensi unik**. Untuk tiap referensi dicatat: carrier (layout/animasi), kelas dan helper di kode, pemetaan menurut aturan resolver, kandidat berdasarkan nama (hanya kandidat), aturan yang dipakai (`rule`) dan bukti.

Aturan klien yang dibaca dari kode (bukti utama): path tanpa tag dipetakan ke `Content/lang/images/` (lokal), path bertag `[DOWNLOAD_CONTENT]` dan helper `BasePath.get*Path` ke `Config.assetHost` (server), `BattleBackground` membangun URL server, `PreDownloader` memetakan kategori ke server. Rincian: `docs/ORIGINAL_FINDINGS.md`.

| Kelompok | Jumlah | Isi |
|---|---|---|
| Ditemukan di APK dan di aset proyek | 6 | `battle/attack_now.png`, `card/bb_mergexp_btn_n/p.png` (nama penuh dan nama polos di dalam tabel), `btl_status_skillp_base.png` |
| Memang dimuat dari server | 5 | `/DownloadContent/lang/cutscene/cutin_frozen.png` (penanda), `battle_bg/swamp01.png`, `battle_bg/gacha01.png`, `arena_bg/default.png` (BattleBackground), `s5.png` (`getRegionMapPath`) |
| Bukan referensi file | 14 | 6 contoh SDK di komentar `/* */` (`Content/ballfx.png`, `sprite.png`, `tank.png`, `example.png`, `internal/path/to/resource.png`, `render-target.png`), 7 sufiks/fragmen (`_n`, `_p`, `_base`, `_low`, `_locked`, `_unlocked`, `s.png`), 1 default mati (`post_effect/lava.png`, metodenya mengembalikan literal lain) |
| Belum terselesaikan | 56 | klien mengharapkan file lokal yang tidak ada di kedua APK dan tidak ada penanda server |

Rincian 56 belum terselesaikan (sub-alasan): 35 hanya muncul di data layout/animasi, 11 dirujuk kode tetapi target tidak ada, 5 punya kandidat nama yang **belum terbukti sama** (mis. `common/ui/guide_left_off.png` vs `common/ui/arrow/guide_left_off.png`), 4 path typo `lang/iamges/common/pact/…`, 1 sheet yang tidak dibundel (`deprecated_loot/sheet1.png`).
Carrier terbesar: layout `LoginBase` (13, `easylogin/*`), animasi `CutInHalloweenBoss` (10), `PumpkinCutin` (3), `Effect/Effect41` dan `Effect42` (7), `pactAnimation` (4), `UIDebug` (3). Layout seperti `Prologue`, `RegionSelector`, `UIDebug`, `Effect41/42` tidak punya pemanggilan statis di kode, tetapi itu **tidak** dibuktikan sebagai tidak terpakai.
Himpunan 74 dari audit B: 5 ditemukan, 4 server, 14 bukan referensi, 51 belum terselesaikan. Tidak ada referensi yang disimpulkan "hilang"; "belum terselesaikan" berarti target lokal yang diharapkan tidak ada di APK dan sumbernya belum terbukti.

## 5. Integrasi ke proyek Godot (tanpa mengubah gameplay, mekanik, balancing, atau battle engine)
| Placeholder lama | Aset asli sekarang | Bukti kode | File |
|---|---|---|---|
| Latar daftar zone (`background.png`) | `common/world/worldmap.png` penuh layar | layout `RegionSelect`: sprite `map` 320x480 di (0,0) | `adventure.gd` |
| Angka damage/heal berupa `Label` | imagefont `blackframe`, tinggi 16, putih (damage) dan `[0, 0.5, 0.5]` (heal), naik 10 px | `DamageNumberMotion` | `ui.gd` (`image_text`), `battle.gd` |
| (tidak ada intro) | `opening_01.ogv` lalu `opening_02.ogv`, ketuk untuk lewati | `PrologueScene` / `OpeningMovie` | `opening.gd`, `title.gd`, `more.gd` |
| Font UI | `trb.ttf` tetap (sudah benar) | `BBSPFontManager` preset `default`; `lt.ttf` = preset `bold` | `ui.gd` |
Loader: `Assets.tex()` kini juga membaca `assets/extracted_v2/images/`; ditambah `Assets.video()` dan `Assets.imagefont()`.

**Sengaja tidak diganti (bukti belum cukup):** header (`HeaderLayout` memakai `red_icicle_top.png` setinggi 62 px, akan menggeser tata letak seluruh layar), potret familiar (art kartu di server), latar battle (server), layout dan animasi lain (datanya sudah ada, perlu renderer), tekstur `opening01.png` dan `cut01_*` (komposisinya ada di animasi `ABJSON`, perlu pemutar animasi), 56 rujukan yang belum terselesaikan.
Placeholder yang masih ada: potret familiar/musuh, latar battle dan home, animasi/efek skill, teks "buff UP/DOWN", header, seluruh data master.

**Pengujian:** Godot tidak tersedia di lingkungan ini. Yang diverifikasi: lint (tab, kurung seimbang), 0 referensi fungsi hilang, 44 path sprite yang dirujuk kode semuanya ada, dan logika angka damage direproduksi di luar Godot (render: digit putih dan biru-hijau, lebar 10-12 px, klien ±11).
Perilaku di Godot (impor `.ogv`/PNG, `VideoStreamPlayer`, tween) belum pernah dijalankan.

## 6. Berkas keluaran
`BB2_Part8_extraction_manifest.csv` (621 file: sumber, format, resolusi, ukuran, SHA-256, status integrasi), `BB2_Asset_Audit_inventory_v2.csv` (888 baris, kolom `part8_update`, `extracted_v2_path`, `integration_note`),
`BB2_Asset_Audit_unresolved_refs_v2.csv` (81 referensi). Versi audit sebelumnya tetap utuh.

## 7. Keterbatasan dan hal terbuka
- 56 referensi belum terselesaikan; `configuration.bin` belum didekode; belum ada pengujian di Godot.
- Data layout/animasi hanya JSON mentah: renderer yang membacanya belum ada (disarankan sebagai langkah berikut).
- `opening_01.ogv` lebih pendek 0,37 detik.
- Aset DeNA (`assets/extracted_v2`, `data/original_extract`) tidak boleh dipublikasikan; dikecualikan dari paket code-only.
