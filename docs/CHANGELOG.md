# Changelog

## 2026-11-14 - v0.1 kerangka awal
- File: seluruh proyek (project.godot, scripts/, scenes/main.tscn, export_presets.cfg, workflow build APK)
- Isi: menu, peta dunia 4 area, 5 level per area, level masak, buku resep, toko upgrade, simpan JSON
- Hasil uji: BELUM diuji. Godot tidak terpasang di lingkungan penulisan; kode ditulis tanpa dijalankan.

## 2026-11-14 - perbaikan build APK
- File: project.godot, export_presets.cfg, .github/workflows/build-apk.yml
- Penyebab error ekspor: kompresi tekstur ETC2/ASTC belum aktif (wajib untuk ekspor Android renderer Mobile); sebelumnya juga path Java/Android SDK dan build-tools 34 belum diatur
- Hasil uji: menunggu hasil GitHub Actions

## 2026-11-14 - uji render nyata
- File: scripts/main.gd (opsi uji `-- --screen=NAMA --area=N --level=N`)
- Hasil uji: Godot 4.3 dijalankan di Xvfb + lavapipe (Vulkan CPU) dengan Movie Maker; menu, peta dunia, pilih level, level masak, toko, dan buku resep tampil tanpa error skrip. Interaksi sentuh belum diuji.

## 2026-11-14 - latar menu beranimasi
- File: assets/menu_bg.jpg (gambar buatan user), scripts/ui/animated_bg.gd (baru), scripts/screens/menu_screen.gd
- Isi: latar gambar + efek kode (uap CPUParticles2D, kilau lentera/lampu/api/matahari, zoom dan geser kamera pelan); judul di dalam kartu semi-transparan
- Hasil uji: dirender di Godot 4.3 (Xvfb + lavapipe), 120 frame tanpa error; frame berbeda antar waktu (animasi berjalan). Belum diuji di HP.
