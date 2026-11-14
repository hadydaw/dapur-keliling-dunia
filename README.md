# Dapur Keliling Dunia

Game masak time management keliling dunia. Godot 4.3, Android landscape, bahasa Indonesia.
Terinspirasi dari genre game masak time management; semua nama, hidangan, dan tampilan di sini orisinal.

## Isi saat ini (v0.1)
- 4 area dunia (Indonesia, Meksiko, Jepang, Prancis), tiap area 5 level dan 4 hidangan khas
- Level masak: pelanggan datang, masak, ketuk matang untuk melayani, bonus bila pelanggan masih sabar, bisa gosong
- Bintang 1-3 per level, area terbuka lewat total bintang
- Toko upgrade (slot masak, kecepatan, kesabaran, harga), Buku Resep, simpan otomatis

## Build APK
Tab **Actions** > **Build APK (debug)** > **Run workflow**, lalu unduh artifact `dapur-keliling-dunia-apk`.
Status: workflow belum pernah dijalankan.

## Struktur
- `scripts/game_data.gd` data hidangan, area, rumus level
- `scripts/game_state.gd` koin, bintang, upgrade, simpan (JSON)
- `scripts/ui_kit.gd` helper UI; `scripts/screens/` tiap layar
