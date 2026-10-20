# Attendance Type Fixes Plan

Created: 2026-08-26

## Objective
Memperbaiki temuan review implementasi attendance type picker: silent fallback WFO saat radio hilang (F1), variabel mati di test helper (F2), tipe terpilih tidak terlihat di dashboard (F3), dokumentasi perilaku auto-run setelah simpan kredensial (F4).

## Tasks
- [x] Fix 1 — JS contract: radio wajib untuk non-WFO (`missing-flag-location`), mapper status, unit tests
- [x] Fix 2 — helper test picker tanpa variabel mati
- [x] Fix 3 — ActionPanel menampilkan "Last attendance type" + widget test
- [x] Fix 4 — catatan PROJECT_MEMORY untuk alur auto-run pasca kredensial
- [x] Verifikasi: dart format, flutter analyze, flutter test

## Risks
- Perubahan kontrak string JS — mitigasi unit test eksplisit kedua cabang (WFO toleran vs non-WFO fatal)
- Fix 3 mengubah signature DashboardView/ActionPanel — parameter optional, widget test existing tidak rusak

## Progress Log
- 2026-08-26 — Rencana dibuat dari hasil code review; user menyetujui eksekusi semua fix.
- 2026-08-26 — Semua fix selesai. Fix 1: `prepareAttendanceFormJs` mengembalikan `missing-flag-location` jika radio hilang untuk non-WFO (WFO tetap toleran); mapper status ditambahkan. Fix 3: parameter optional `selectedTypeLabel` pada DashboardView/ActionPanel, subtitle "Last attendance type: X" di atas tombol Run. Hasil: **81/81 test lulus, flutter analyze bersih**.
