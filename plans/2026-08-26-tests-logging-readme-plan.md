# Tests, Logging, Gitignore & README Plan

Created: 2026-08-26

## Objective
Membuat aplikasi HRMIS Helper dapat diuji (unit + widget tests), menghilangkan `print()` dengan logger yang release-safe, mengabaikan file lokal/agent di git, dan memperbarui dokumentasi README.

## Scope
- Ekstraksi logic murni dari `lib/main.dart` ke modul `lib/core/` tanpa mengubah perilaku
- Implementasi unit tests dan widget tests di `test/`
- Penggantian 22 pemanggilan `print()` dengan helper `log()` release-safe
- Pembaruan `.gitignore` untuk 6 item untracked
- Refresh README (hapus setup `.env`, struktur proyek baru, section testing)

## Milestones
1. Housekeeping (.gitignore)
2. Refactor testability (`lib/core/`)
3. Logging release-safe
4. Unit tests
5. Widget tests (DashboardView diekstrak)
6. Dokumentasi (README, PROJECT_MEMORY)

## Tasks
- [x] Update `.gitignore`: tambah `.mimocode/`, `PROJECT_MEMORY.md`, `.memory/`, `system_prompt.md`, `view_source_hrmis/`, `assets/images/mai-image-*`, `assets/images/qwen-image-*`
- [x] Ekstrak core logic: `lib/core/hrmis_uri.dart`, `attendance_summary.dart`, `javascript_result.dart`, `status_messages.dart`
- [x] Buat `lib/core/app_logger.dart` dan ganti semua `print()` (19 main.dart, 3 config.dart)
- [x] Unit tests: hrmis_uri_test, attendance_summary_test, javascript_result_test, status_messages_test
- [x] Ekstrak `DashboardView` + enum status ke modul publik
- [x] Widget tests: dashboard_view_test, credential_screen_test, about_screen_test
- [x] Update README.md
- [x] Append entri PROJECT_MEMORY.md

## Risks
- Refactor menyentuh `main.dart` besar — mitigasi: perubahan mechanical, tanpa ubah logika
- Widget test AboutScreen/CredentialScreen bergantung stub MethodChannel — bisa rapuh saat dependency major-upgrade
- `debugPrint` masih mencetak di profile mode; hanya release yang diam
- Scope test tidak mencakup flow InAppWebView automation (butuh mock berat, flaky-prone)

## Progress Log
- 2026-08-26 — Rencana dibuat setelah analisis repo dan konfirmasi user (implement penuh, logger release-safe, ignore semua untracked).
- 2026-08-26 — Eksekusi selesai. Semua task checked. Catatan: sed awal menghapus kurung penutup `_handleLoadStop` — sudah diperbaiki manual; `dart format` lolos tanpa error sintaks di seluruh lib/ dan test/. `flutter analyze` dan `flutter test` diserahkan ke user sesuai aturan global.
- 2026-08-26 — Perbaikan hasil `flutter analyze` dari user: tambah import `core/attendance_summary.dart` yang tertinggal di main.dart, rename pemanggilan `_DashboardView(` → `DashboardView(` yang terlewat sed, hapus field `_formPath` tak terpakai, tambah import services di about_screen_test, hapus import tak terpakai + ganti asersi `obscureText` ke widget `EditableText` di credential_screen_test. `dart format` lolos (0 changed).
- 2026-08-26 — Eksekusi test penuh (atas permintaan user) dan perbaikan: (1) raw `setMessageHandler` dengan Future null membuat channel menunggu selamanya → ganti ke `setMockMethodCallHandler` di credential_screen_test; (2) `PackageInfo.setMockInitialValues` menyimpan cache statis lintas test → error-path test dibuat deterministik dengan mock throwing dan dipindah ke urutan pertama file; (3) ekspektasi `'""'` dikoreksi jadi `''`. Hasil akhir: **64/64 test lulus, flutter analyze bersih**.

## Notes
- Verifikasi mengikuti aturan global: agent hanya menjalankan `dart format`; `flutter analyze`, `flutter test`, dan build diserahkan ke user.
- Commit usulan (terpisah): `chore: ignore local agent and design assets` · `refactor: extract testable core logic from attendance page` · `test: add unit and widget tests for core logic and dashboard` · `chore: use release-safe logger and refresh README`
