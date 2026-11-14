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

## 2026-11-14 - Kunci tanda tangan APK tetap
- File: keystore/debug.keystore (baru), .github/workflows/build-apk.yml, .gitignore
- Masalah: tiap build membuat keystore baru, jadi APK baru "bentrok dengan paket yang sudah ada" dan tidak bisa menimpa versi lama di HP
- Perbaikan: keystore debug tetap disimpan di repo dan dipakai tiap build. Hanya untuk debug, bukan rilis Play Store
- Dampak: versi yang sudah terpasang (kunci lama) harus dihapus SEKALI; setelah itu update langsung menimpa
- Hasil tes: lihat verifikasi tanda tangan APK hasil build di laporan

## 2026-11-14 - Latar menu memenuhi layar (tanpa pinggiran gelap)
- File: scripts/ui/animated_bg.gd
- Masalah: di HP 20:9 video tampil "muat semua" dengan pinggiran gambar gelap di kiri dan kanan
- Perbaikan: mode cover (video menutupi layar, kelebihan dipotong simetris); gambar latar gelap tambahan dihapus
- Dampak: di 20:9 sedikit bagian atas/bawah video terpotong; di 16:9 tampilan sama. Posisi UI tidak berubah (dihitung dari layar)
- Hasil tes: render asli 2400x1080 dan 1280x720 tanpa pinggiran; tes ketuk 13/13 lulus. Belum diuji di HP.

## 2026-11-14 - Tes otomatis gameplay + simulasi keseimbangan
- File: tests/gameplay_test.gd, tests/gameplay_test.tscn (baru; tidak mengubah kode game)
- Cakupan (18 cek, semua lulus): masak->matang, gosong, buang gosong, layani, bayar, tip 25%, pesanan ganda, sabar habis, ambang bintang 0/1/2/3, simpan progres, plus ketuk sungguhan di slot
- Simulasi bot (pemain ideal, reaksi 0,6 dtk, 3 percobaan/level, 20 level): bot mencapai 184-241% target, jadi 3 bintang (butuh 180%) hampir selalu tercapai oleh pemain sempurna -> target kemungkinan terlalu mudah. Belum diubah; menunggu keputusan pemilik.
- Belum diuji: rasa bermain manusia di HP

## 2026-11-14 - Peta Dunia dengan latar peta baru
- File: scripts/screens/world_map_screen.gd (ditulis ulang), scripts/ui/star_icon.gd (baru), assets/world_map_bg.jpg (latar dari pemilik), tests/world_map_test.gd + .tscn
- Tampilan: latar peta penuh layar (cover, potong dari bawah lebih banyak agar menara Eiffel tetap terlihat), papan nama per pulau (nama, negara, bintang X/15), pulau terkunci diredupkan + papan abu "Terkunci / Butuh N bintang"; bar koin/bintang, tombol Resep, Toko, dan kembali di atas
- Interaksi: ketuk pulau -> pilih level; ketuk pulau terkunci -> pesan "Kumpulkan N bintang lagi"; animasi ketuk sama seperti menu
- Sementara kode: papan nama, ikon bintang, tombol kembali digambar kode (aset prompt peta belum dikirim); bisa diganti aset
- Hasil tes: peta 16/16 lulus, menu 13/13 lulus; render asli 1280x720 dan 2400x1080. Belum diuji di HP.

## 2026-11-14 - Peta Dunia memakai aset gambar (papan nama, bintang, gembok, panah)
- File: scripts/screens/world_map_screen.gd, assets/ui/{plate_nama,star_full,star_empty,btn_back,ic_gembok}.png (baru, transparan), scripts/ui/star_icon.gd (dihapus, diganti aset)
- Perubahan: papan nama, bintang penuh/kosong, tombol panah kembali, dan gembok di tengah pulau terkunci kini dari aset pemilik; teks (nama, bintang X/15, "Butuh N") tetap digambar kode. Area teks papan dua baris: nama dan bintang (negara dihapus karena papan terlalu pendek)
- Hasil tes: peta 16/16, menu 13/13 lulus; render asli 1280x720 (progres awal) dan 2400x1080 (15 bintang). Belum diuji di HP.

## 2026-11-14 - Pilih Level dengan latar per area
- File: scripts/screens/level_select_screen.gd (ditulis ulang), scripts/ui/level_medal.gd (baru), assets/level_bg_{indonesia,meksiko,jepang,prancis}.jpg (latar dari pemilik), tests/level_select_test.gd + .tscn
- Tampilan: latar pemandangan tiap area, papan nama area di atas, bar koin, tombol kembali, 5 medali level berjalur lengkung ringan; tiap level menampilkan 3 bintang dan target; level terkunci memakai medali gembok
- Interaksi: ketuk level terbuka -> gameplay; level terkunci -> pesan "Selesaikan Level N dulu"; animasi ketuk sama seperti layar lain
- Sementara: medali level terbuka digambar kode (aset lvl_open.png belum ada; otomatis dipakai bila ditambahkan ke assets/ui/); medali terkunci memakai ic_gembok.png
- Hasil tes: Pilih Level 16/16, Peta 16/16, Menu 13/13 lulus; render asli 1280x720 (Indonesia) dan 2400x1080 (Prancis). Belum diuji di HP.

## 2026-11-14 - Font game dan penempatan teks presisi
- File: assets/fonts/* (Lora variabel bobot 700, Poppins Bold, game_font.tres), project.godot ([gui] font bawaan), scripts/ui_kit.gd (fit_label), menu_screen.gd, world_map_screen.gd, level_select_screen.gd, ui/level_medal.gd
- Alasan: semua teks memakai font bawaan Godot yang sama dan posisinya tidak pas di papan/bar/medali.
- Perubahan: font bawaan proyek diganti; teks ditempatkan di area kayu kosong hasil ukur piksel aset (plate_nama, bar_koin, bar_bintang); ukuran font mengikuti tinggi kotak lalu dikecilkan bila tidak muat; baris bintang peta dunia dipindah ke bawah papan dan dipusatkan; angka medali dipusatkan dengan garis dasar yang dihitung dan diberi outline.
- Platform diuji: render 1280x720 (Menu, Peta Dunia, Pilih Level) lewat Godot + lavapipe; belum diuji di HP.
- Hasil tes: menu_test, world_map_test, level_select_test, gameplay_test semuanya 0 gagal.
- Catatan: font game tebal bergaya (Lilita One/Baloo/Fredoka) tidak bisa diunduh dari sandbox; sementara memakai Lora. Bisa diganti dengan TTF dari user.

## 2026-11-14 - Koreksi pemusatan teks (tahap 2)
- File: scripts/ui_kit.gd (fit_label)
- Alasan: teks masih terlihat turun di papan nama dan bar; kotak baris teks dipusatkan, bukan huruf.
- Perubahan: fit_label kini memusatkan huruf (garis dasar dihitung dari ascent font, pusat huruf = garis dasar - 0,35 em) di tengah area kayu; diukur ulang dari aset (kayu bersih berpusat ~0,52 tinggi aset).
- Diuji: render 1280x720 diperbesar dan dicek; medali "1" juga terpusat di lingkaran dalam. Belum diuji di HP.
- Hasil tes: menu, peta dunia, pilih level, gameplay semuanya 0 gagal.

## 2026-11-14 - Layar Main: tombol Jeda bergambar
- File: assets/ui/btn_jeda.png, scripts/ui_kit.gd (icon_button), scripts/screens/gameplay_screen.gd, tests/gameplay_test.gd
- Alasan: mulai mengganti tampilan layar Main dengan aset asli, satu per satu.
- Perubahan: tombol Jeda lama (kotak ungu) diganti gambar bulat emas-kayu dengan animasi ketuk; helper UI.icon_button dipakai ulang untuk tombol bergambar berikutnya.
- Hasil tes: gameplay_test ditambah 3 cek (ukuran >=44px, ketuk membuka jeda, jeda bisa ditutup), semua tes 0 gagal. Belum diuji di HP.

## 2026-11-14 - Layar Main gaya Cooking Madness (Indonesia)
- File: assets/scene_indonesia.jpg (latar dari user), scripts/screens/gameplay_scene_screen.gd (baru), scripts/game_data.gd (RECIPES, APPLIANCE_NAMES, SCENES, menu Ikan Bakar), scripts/main.gd (routing), scripts/screens/gameplay_screen.gd (flag classic), tests/gameplay_scene_test.gd/.tscn (baru), tests/gameplay_test.gd, tests/level_select_test.gd
- Alasan: user ingin game seperti Cooking Madness: latar penuh, pelanggan di depan konter, alur bahan -> alat masak -> piring -> pelanggan.
- Perubahan: layar baru memakai satu latar dengan area ketuk tak terlihat di atas rak bahan, 3 gelas, 6 panggangan, 4 wajan, 4 panci, 6 piring, 6 mangkuk. Slot aktif 2 + level upgrade "slot" (maks. fisik); sisanya diredupkan. Es teh tidak gosong; masakan lain gosong bila terlambat. Menu ke-5 Ikan Bakar dibuka di level 5. Logika pelanggan, bayar, jeda, bintang dipakai ulang dari layar lama. Layar lama tetap untuk area tanpa latar (Meksiko, Jepang, Prancis) dan untuk tes classic.
- Sementara: masakan, pelanggan, dan gelembung pesanan digambar dari kode (lingkaran huruf, siluet) sampai aset ikon dan pelanggan asli ada. Bar target dan HUD juga sementara.
- Diuji: gameplay_scene_test 20 cek (ketukan sungguhan, semua area ketuk >=44px di 1280x720), render 1280x720 dan 2400x1080. Semua tes lain 0 gagal. Belum diuji di HP. Keseimbangan (target level) belum disimulasi ulang untuk mekanik baru.

## 2026-11-14 - Proses es teh: dispenser penuh, gelas terisi, timer jam pasir
- File: assets/scene/indo_dispenser_penuh.png, indo_gelas_0..2.png (dipotong dari 2 gambar user), scripts/game_data.gd (JAR_CAPACITY, JAR_FILL_TIME, data "dispenser" di SCENES, resep es_teh "refill"), scripts/screens/gameplay_scene_screen.gd, tests/gameplay_scene_test.gd
- Alasan: permintaan user: ketuk termos es -> dispenser terisi penuh dengan timer jam pasir (gelas tetap kosong); ketuk dispenser -> gelas pertama terisi dengan timer; gelas matang diketuk untuk disajikan.
- Perubahan: dispenser punya status kosong/terisi/penuh dengan kapasitas 4 gelas (konstanta di game_data, bisa diubah), lalu perlu isi ulang. Timer lingkaran dengan jam pasir beranimasi di dispenser dan di tiap gelas yang terisi. Es teh tetap tidak gosong.
- Catatan: keadaan "kosong" masih memakai dispenser latar lama yang ukurannya lebih kecil dari dispenser baru, jadi ada sedikit perubahan ukuran saat terisi; akan rapi bila ada gambar dispenser kosong bergaya baru.
- Diuji: gameplay_scene_test 30 cek (ketukan sungguhan), render 5 tahap. Semua tes lain 0 gagal. Belum diuji di HP.

## 2026-11-14 - Pelanggan bergambar (3 ekspresi)
- File: assets/customers/pria_batik_{senang,biasa,marah}.png (dipotong dari gambar user), scripts/game_data.gd (customer_art, posisi customer_spots, MOOD_*), scripts/screens/gameplay_scene_screen.gd, tests/gameplay_scene_test.gd
- Perubahan: siluet sementara diganti pelanggan bergambar (kepala + bahu, berdiri di celah antar alat masak). Ekspresi mengikuti sisa kesabaran: senang di atas 55%, biasa 25-55%, marah di bawah 25% (konstanta di game_data). Bar kesabaran dan gelembung pesanan di atas kepala; posisi diatur agar tidak menabrak HUD di layar 16:9 maupun 20:9. Sementara semua pelanggan memakai orang yang sama.
- Diuji: 4 cek baru (ekspresi per kesabaran, tekstur termuat), render 1280x720 dan 2400x1080. Semua tes lain 0 gagal. Belum diuji di HP.

## 2026-11-14 - Pelanggan lebih besar, gelembung pesanan vertikal berisi ikon + bar kesabaran
- File: scripts/screens/gameplay_scene_screen.gd, scripts/game_data.gd (tinggi pelanggan 168, spot kanan 1466)
- Alasan: pelanggan terlalu kecil; gelembung dibuat vertikal di kanan pelanggan, tanpa teks; bar kesabaran pindah ke dalam gelembung (vertikal, kanan ikon)
- Dampak: layar gameplay berbasis scene (area Indonesia)
- Platform yang diuji: render 1280x720 dan 2400x1080 (20:9); belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)

## 2026-11-14 - Pelanggan berdiri di belakang konter (tidak dipotong)
- File: scripts/screens/gameplay_scene_screen.gd (lapisan pelanggan + Polygon2D konter), scripts/game_data.gd (counter_mask, spot y 446, tinggi 200)
- Alasan: gambar pelanggan terpotong di dada; kini kaki disembunyikan konter yang digambar menimpa pelanggan
- Platform yang diuji: render 1280x720 dan 2400x1080; belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)

## 2026-11-14 - Pelanggan ditinggikan (tidak tampak tenggelam)
- File: scripts/game_data.gd (spot y 426, tinggi 215, mask kiri), scripts/screens/gameplay_scene_screen.gd (gelembung di bawah panel waktu)
- Platform yang diuji: render 1280x720 dan 2400x1080; belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)

## 2026-11-14 - Ikon Es Teh di gelembung pesanan
- File: assets/icons/es_teh.png (+ .import), scripts/game_data.gd (DISHES.es_teh.icon), scripts/screens/gameplay_scene_screen.gd (cache ikon `icon_tex`, ukuran 60)
- Catatan: ikon di-cache saat layar dibuka; memuat tekstur tiap frame membuat ikon tampil putih
- Platform yang diuji: render 1280x720 dan 2400x1080; belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)

## 2026-11-14 - Resep sate: 4 tahap bergambar + ikon sate
- File: assets/scene/sate/*.png (24 potongan: mentah/matang/gosong per slot pemanggang + sate di piring per slot piring), assets/icons/sate_ayam.png, scripts/game_data.gd (stage_art, icon sate), scripts/screens/gameplay_scene_screen.gd (`_draw_stage_art`, cache `art_tex`, slot punya `idx`)
- Alasan: sate mentah/matang/gosong tampil di atas pemanggang dan sate jadi di atas piring, menggantikan lingkaran berhuruf; ikon sate di gelembung pelanggan
- Catatan: potongan diambil dari 4 gambar latar buatan user (sejajar dengan latar dasar, selisih maks 1 px); uap/asap di atas pemanggang tidak ikut dipotong
- Platform yang diuji: render 1280x720 dan 2400x1080; belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)

## 2026-11-14 - Resep nasi goreng: 4 tahap bergambar + ikon
- File: assets/scene/nasi/*.png (wajan mentah/matang/gosong x4 slot, nasi goreng di piring x6), assets/icons/nasi_goreng.png, scripts/game_data.gd (stage_art nasi_goreng, rect "wok", icon), scripts/screens/gameplay_scene_screen.gd (radius cincin timer dibatasi 40 agar tidak menimpa wajan tetangga)
- Catatan: potongan wajan berbentuk elips (tepi memudar); uap/asap pada gambar sumber tidak ikut dipotong
- Platform yang diuji: render 1280x720 dan 2400x1080; belum diuji di perangkat asli
- Hasil tes: 5 suite headless lulus (0 gagal)
