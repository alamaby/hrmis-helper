# Randomisasi Deskripsi Absensi Bilingual (EN/ID) — 30 Pilihan

Created: 2026-08-31 07:55:40

## Objective
Mengganti deskripsi absensi yang saat ini hardcoded satu kalimat (`'Bismillah, semangat bekerja!'` di `lib/core/attendance_prepare_js.dart:3`) menjadi **acak dari 30 deskripsi bilingual** (bahasa Inggris + Indonesia, tema senada: motivasi kerja). Setiap sesi absen dipilih **satu deskripsi + satu bahasa secara acak** (tidak digabung dua bahasa dalam satu teks).

## Scope
- File baru `lib/core/attendance_descriptions.dart` (kelas, 30 entri, fungsi pick acak).
- Ubah `lib/core/attendance_prepare_js.dart` (param `required String description`).
- Ubah `lib/main.dart` (pick sekali per sesi absen, sebelum loop retry).
- Update `test/attendance_type_test.dart` + buat `test/attendance_descriptions_test.dart`.
- Bump versi `pubspec.yaml` → `1.4.0+9`.

## Temuan Analisa Repo
- Tidak ada HTTP call langsung; deskripsi disuntikkan ke form HRMIS via JavaScript injection di `prepareAttendanceFormJs()` (`lib/core/attendance_prepare_js.dart:104`).
- Fungsi prepare dijalankan dalam **loop retry maks 5 percobaan** (`lib/main.dart:513`), jadi randomisasi HARUS dipanggil **sekali di luar loop** lalu diteruskan sebagai parameter — jika di-random di dalam builder JS, deskripsi bisa berubah antar percobaan retry.
- Tidak ada l10n/intl di repo — semua string hardcoded, jadi daftar bilingual cukup sebagai konstanta Dart biasa (konsisten dengan pola existing).
- Tidak ada `dart:math`/`Random` yang dipakai — helper randomisasi adalah kode baru.

## Design
1. **File baru `lib/core/attendance_descriptions.dart`**:
   - Kelas immutable `AttendanceDescription { final String english; final String indonesian; }`.
   - `const List<AttendanceDescription> kAttendanceDescriptions` berisi 30 entri.
   - `String pickRandomAttendanceDescription([Random? random])` — pilih 1 dari 30 entri acak, lalu pilih 1 dari 2 bahasanya secara acak. Parameter `Random` opsional agar bisa di-seed untuk pengujian deterministik.
2. **`lib/core/attendance_prepare_js.dart`**: hapus `kAttendanceDescriptionText`; ubah signature menjadi `prepareAttendanceFormJs(AttendanceType type, {required String description})`; line 104 memakai `$description`.
3. **`lib/main.dart`**: di `_injectAttendanceForm()` sebelum loop retry prepare (~line 490), pilih sekali: `final description = pickRandomAttendanceDescription();` + log deskripsi terpilih, lalu teruskan ke `prepareAttendanceFormJs(_selectedAttendanceType, description: description)`.
4. **Keamanan string JS**: deskripsi disuntik ke string single-quoted JavaScript — seluruh 30 entri ditulis **tanpa apostrofe (`'`), backslash, atau newline**, dan dijaga oleh unit test.

## Milestones
1. Phase 1 — Kode inti: daftar deskripsi + builder JS + main.dart.
2. Phase 2 — Test: update test lama, test baru untuk daftar & picker.
3. Phase 3 — Verifikasi penuh (pub get, analyze, test, build apk) + version bump + memory.

## Daftar 30 Deskripsi (EN → ID, campuran: 7 sentuhan spiritual)
1. Ready to work hard today! → Siap bekerja keras hari ini!
2. A new day, a new spirit. → Hari baru, semangat baru.
3. Looking forward to a productive day. → Semoga hari ini produktif.
4. Bismillah, let us start the day with full energy! → Bismillah, mari mulai hari dengan energi penuh!
5. Focused and ready to deliver. → Fokus dan siap memberikan yang terbaik.
6. Another great day to grow and learn. → Hari yang baik untuk tumbuh dan belajar.
7. Alhamdulillah, still given the chance to work today. → Alhamdulillah, masih diberi kesempatan bekerja hari ini.
8. Small steps every day, big results over time. → Langkah kecil setiap hari, hasil besar di masa depan.
9. Teamwork makes the work lighter. → Kerja sama membuat pekerjaan lebih ringan.
10. Staying positive and productive today. → Tetap positif dan produktif hari ini.
11. Time to shine and do the best work. → Saatnya bersinar dan memberikan yang terbaik.
12. Bismillah, may today run smoothly. → Bismillah, semoga hari ini lancar.
13. Every task is a chance to improve. → Setiap tugas adalah kesempatan untuk berkembang.
14. Bringing good energy to the workplace. → Membawa energi positif ke tempat kerja.
15. Consistency is the key to success. → Konsistensi adalah kunci kesuksesan.
16. Ready to face any challenge today. → Siap menghadapi tantangan apa pun hari ini.
17. Work with heart, finish with pride. → Bekerja dengan hati, selesaikan dengan bangga.
18. May today be smooth and blessed. → Semoga hari ini lancar dan penuh berkah.
19. Discipline today, achievement tomorrow. → Disiplin hari ini, prestasi esok hari.
20. Happy to start another working day. → Senang memulai hari kerja lagi.
21. Bismillah, keep the spirit up! → Bismillah, semangat bekerja!
22. Do the best, expect the best. → Lakukan yang terbaik, harapkan yang terbaik.
23. A productive day starts with a good intention. → Hari produktif dimulai dengan niat yang baik.
24. Stay focused, stay humble. → Tetap fokus, tetap rendah hati.
25. Alhamdulillah for the energy to work today. → Alhamdulillah atas energi untuk bekerja hari ini.
26. Turning plans into action today. → Mengubah rencana menjadi tindakan hari ini.
27. Good attitude, good results. → Sikap yang baik, hasil yang baik.
28. One task at a time, all will be done. → Satu tugas demi satu tugas, semua akan selesai.
29. Bismillah, today is another chance to be better. → Bismillah, hari ini kesempatan lagi untuk lebih baik.
30. Finish strong, start stronger. → Selesaikan dengan kuat, mulai lebih kuat.

## Tasks
- [x] Buat file rencana `plans/2026-08-31-random-attendance-description-plan.md` (dokumen ini).
- [x] Buat `lib/core/attendance_descriptions.dart` (kelas, 30 entri konstanta, `pickRandomAttendanceDescription`).
- [x] Ubah `lib/core/attendance_prepare_js.dart`: hapus konstanta lama, tambah param `required String description`.
- [x] Ubah `lib/main.dart`: pilih deskripsi sekali sebelum loop retry, teruskan sebagai parameter, tambah log.
- [x] Update `test/attendance_type_test.dart`: semua pemanggilan `prepareAttendanceFormJs` memakai deskripsi eksplisit; assertion `contains` memakai deskripsi yang dikirim.
- [x] Buat `test/attendance_descriptions_test.dart`: tepat 30 entri; tidak ada `'`/`\`/newline di semua entri; hasil pick selalu anggota pool; dengan seed berbeda hasil bervariasi (>1 teks unik dan kedua bahasa muncul dalam 1000 pick).
- [x] Bump versi `pubspec.yaml`: `1.3.1+8` → `1.4.0+9` (fitur baru: minor +1, patch reset, build +1).
- [x] Verifikasi: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --split-per-abi`.
- [x] Inisialisasi `.memory/README.md` (PROJECT_MEMORY.md sebagai arsip legacy) + entri `.memory/` untuk fitur ini.

## Risks
- **Karakter berbahaya di JS string**: apostrofe/backslash akan merusak injeksi JS — dimitigasi dengan aturan penulisan + test guard otomatis.
- **Random bisa mengulang deskripsi yang sama di hari berbeda** (probabilistik, bukan shuffle tanpa pengulangan). Untuk kebutuhan ini diterima; jika nanti ingin anti-repetisi berurutan, bisa ditambah memori deskripsi terakhir di secure storage (di luar scope saat ini).
- **Retry loop tidak mengubah deskripsi**: sudah dimitigasi dengan desain pick-sekali-di-luar-loop.
- Risiko aplikasi/situs: HRMIS menerima deskripsi sebagai teks bebas, variasi teks tidak mengubah alur submit sama sekali.

## Progress Log
- 2026-08-31 07:55:40 — Rencana dibuat setelah analisa repo dan konfirmasi preferensi user (format: acak pilih salah satu bahasa; gaya: campuran). Implementasi belum dimulai.
- 2026-10-19 — Fitur sudah live sejak 1.4.0+9. Terverifikasi: 30 entri di `lib/core/attendance_descriptions.dart`, `pickRandomAttendanceDescription()` dipakai `lib/main.dart:656`, `prepareAttendanceFormJs` menerima `required String description`, dan `test/attendance_descriptions_test.dart` ada. Checkbox diselaraskan dengan kenyataan; tidak ada perubahan kode.

## Notes
- Format dipilih user: acak pilih **salah satu bahasa** per absen (bukan gabungan EN + ID).
- Gaya dipilih user: campuran — mayoritas motivasi netral, ±7 entri dengan sentuhan "Bismillah"/"Alhamdulillah" (mengikuti gaya deskripsi saat ini).
- Tidak ada perubahan alur GPS/radio WFO-WFH-SPJ; hanya field deskripsi.
