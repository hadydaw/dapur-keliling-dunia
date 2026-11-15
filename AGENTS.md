# AGENTS.md
- Godot 4.7.2, renderer Compatibility (OpenGL ES 3.0, jangkauan HP terluas), GDScript, target Android landscape (1280x720, stretch expand). UI dibangun lewat kode di `scripts/screens/`.
- Semua teks UI dalam Bahasa Indonesia; nama kode dalam Bahasa Inggris.
- Konten (hidangan, area, harga) hanya di `scripts/game_data.gd`, bukan hardcode di logika.
- Tombol sentuh minimal 44x44 px. Jangan andalkan hover.
- Nama, aset, dan desain harus orisinal; jangan menyalin dari game lain.
- Kerja di branch `dev`; jangan push ke `main` tanpa instruksi pemilik repo.
- Catat perubahan di `docs/CHANGELOG.md`. Laporkan hasil uji dengan jujur; tulis "belum diuji" bila belum dijalankan.
