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

## 2026-11-14 - menu utama sesuai mockup user
- File: assets/menu_ui.jpg (mockup user), scripts/screens/menu_screen.gd (ditulis ulang), scripts/ui/animated_bg.gd, tests/menu_test.gd + .tscn
- Isi: gambar penuh sebagai tampilan menu, tombol sentuh transparan di atas tiap tombol, angka koin/bintang asli, konfirmasi Mulai Baru, mode contain untuk layar lebar
- Hasil uji: tests/menu_test.tscn (headless, klik sungguhan) 12/12 lulus pada 1280x720 dan 1600x720; render nyata kedua ukuran tanpa error. Belum diuji di HP.
- Catatan: ikon Piala, Surat, Inventaris, Pengaturan baru menampilkan pesan "segera hadir"; titik merah notifikasi masih bagian dari gambar.

## 2026-11-14 - Menu Utama memakai aset terpisah
- File: scripts/screens/menu_screen.gd, scripts/ui/animated_bg.gd, tests/menu_test.gd, assets/ui/*.png (19 aset transparan, versi Indonesia + Inggris), assets/menu_bg.jpg dipakai sebagai latar
- Alasan: mockup hanya referensi; teks/warna/angka kini bisa diubah tanpa membuat ulang gambar
- Dampak: Menu Utama saja. Angka koin/bintang digambar kode (nilai asli). Tata letak dihitung dari tinggi layar, dipusatkan
- Bahasa: bawaan Indonesia; versi *_en.png disiapkan untuk pilihan bahasa di Setelan (belum terhubung)
- Platform diuji: render asli 1280x720 dan 1600x720 (Xvfb + Godot 4.3); tes ketuk headless 1280x720
- Hasil tes: ketuk 12/12 lulus. Belum diuji di HP.

## 2026-11-14 - Latar menu berupa video loop
- File: scripts/ui/animated_bg.gd, assets/menu_bg.ogv (1,6 MB, 1280x720, 4 detik, 24 fps, tanpa audio)
- Alasan: latar bergerak dari video I2V buatan pemilik; efek kode (uap/kilau) dimatikan saat video ada agar tidak dobel, dan tetap jadi cadangan bila video tidak ada
- Loop: video asli (5 dtk) awal dan akhirnya tidak cocok, jadi dibuat crossfade 1 dtk agar mulus
- Platform diuji: render asli 1280x720 dan 1600x720 (video terbukti bergerak antar frame); tes ketuk 12/12 lulus
- Belum diuji: di HP (performa decoding video Theora di perangkat nyata)

## 2026-11-14 - Animasi ketuk tombol menu
- File: scripts/screens/menu_screen.gd, tests/menu_test.gd
- Perilaku: tombol mengecil ke 92% saat ditekan, membal ke 106% lalu kembali 100% saat dilepas (+ sedikit gelap saat ditekan)
- Hasil tes: tes headless 13/13 lulus (termasuk uji skala saat ditekan dan kembali normal). Belum diuji di HP.
