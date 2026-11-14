# Changelog

## 2026-11-14 - v0.1 kerangka awal
- File: seluruh proyek (project.godot, scripts/, scenes/main.tscn, export_presets.cfg, workflow build APK)
- Isi: menu, peta dunia 4 area, 5 level per area, level masak, buku resep, toko upgrade, simpan JSON
- Hasil uji: BELUM diuji. Godot tidak terpasang di lingkungan penulisan; kode ditulis tanpa dijalankan.

## 2026-11-14 - perbaikan build APK
- File: project.godot, export_presets.cfg, .github/workflows/build-apk.yml
- Penyebab error ekspor: kompresi tekstur ETC2/ASTC belum aktif (wajib untuk ekspor Android renderer Mobile); sebelumnya juga path Java/Android SDK dan build-tools 34 belum diatur
- Hasil uji: menunggu hasil GitHub Actions
