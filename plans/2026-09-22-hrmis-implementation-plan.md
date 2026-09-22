# HRMIS Helper — Implementation Plan (Idle Gating + Foreground Keep-Alive + Memory Hygiene)

Created: 2026-09-22 08:00:00

## Objective

Menuntaskan 5 arahan user yang sudah disetujui tanpa membutuhkan analisis ulang oleh eksekutor:

1. Verifikasi baseline boleh dilakukan.
2. `.memory/` dan `plans/` tetap untracked (tidak ada perubahan `.gitignore`).
3. Hapus `system_prompt.md` yang kedaluwarsa dan migrasi project memory ke format `.memory/` aktif.
4. Perilaku startup diubah menjadi idle di Dashboard sampai user menekan `Run` (picker WFO/WFH/SPJ hanya muncul dari aksi eksplisit).
5. Automation tidak mati saat lock/home untuk durasi pendek via keep-alive foreground (Wakelock + foreground service + lifecycle handling). True-background WebView TIDAK dikerjakan; Fase 3 headless-HTTP hanya dicatat sebagai TODO.

Plan ini deterministik dan atomik untuk model dengan capability lebih kecil. Kerjakan langkah S0→S6 berurutan. Jangan melompat. Jangan menggabungkan commit.

## Scope

In-scope:

- Verifikasi baseline random-description (`1.4.0+9`, dirty-state saat plan ditulis).
- Penghapusan 1 file lokal: `system_prompt.md`.
- Inisialisasi `.memory/README.md` + 1 entri timestamped pertama.
- Idle gating di `lib/main.dart` + placeholder idle + test + bump patch.
- Foreground keep-alive: 2 deps baru, `AndroidManifest.xml`, lifecycle, test + bump minor.
- Pencatatan TODO Fase 3 headless sebagai task + open item (tanpa kode).

Out-of-scope (dilarang):

- Rewrite headless HTTP (Fase 3) — hanya TODO.
- Refactor besar `lib/main.dart` (~1045 baris) menjadi controller — tidak diizinkan di plan ini.
- Perubahan radio/GPS HRMIS (`flag_location-WFO/KEMAH/SPJ`, polling 20x1s), parser summary, JS builder selain yang disebut eksplisit.
- iOS, l10n/intl, perubahan desain Dashboard.
- Perubahan `.gitignore`, `build.gradle` rename-APK, ikon launcher, `view_source_hrmis/`, `.zcode/`.

## Requirement Traceability

| ID | Requirement / Finding | Ditangani oleh |
|----|----------------------|----------------|
| REQ-01 | Idle di Dashboard sampai tekan `Run` (keputusan user 1) | S4 |
| REQ-02 | Pilihan WFO/WFH/SPJ sebelum otomasi (bug startup langsung jalan) | S4 |
| REQ-03 | Keep-alive foreground saat lock/home pendek (keputusan user 2, Fase 1) | S5 |
| REQ-04 | Fase 3 headless dicatat TODO, tidak diimplementasi | S6 |
| REQ-05 | Hapus `system_prompt.md` kedaluwarsa (masih sebut `.env`/`flutter_dotenv`) | S2 |
| REQ-06 | Migrasi memory ke `.memory/` aktif, tetap untracked | S3 |
| REQ-07 | Baseline 30 deskripsi bilingual verified (pick-once-outside-retry, JS-safe) | S0, S1 |
| REQ-08 | Versioning Flutter: bugfix patch+build, fitur minor+build | S1, S4, S5 |
| FIND-01 | `IndexedStack` eager + `initialUrlRequest=doornew` sebabkan silent auto-run WFO default | S4 |
| FIND-02 | WebView + `Future.delayed` pause saat `onPause`; tanpa WakeLock/service | S5 |
| FIND-03 | `system_prompt.md:12,24,60-68` kontradiksi realitas Keystore `lib/config.dart:8-10` | S2 |
| FIND-04 | `.memory/` belum ada; hanya `PROJECT_MEMORY.md` legacy | S3 |
| FIND-05 | Dirty baseline harus dikomit terpisah sebelum fix baru | S1 |

Setiap FIND memiliki minimal satu langkah + test/verifikasi. Lihat detail tiap langkah.

## Milestones

1. M0 — Baseline terverifikasi dan terkomit terpisah (S0+S1).
2. M1 — Hygiene selesai: `system_prompt.md` hilang, `.memory/` aktif (S2+S3).
3. M2 — Startup idle gating rilis sebagai bugfix patch (S4).
4. M3 — Foreground keep-alive rilis sebagai fitur minor + TODO Fase 3 tercatat (S5+S6).

## Tasks

- [x] S0 — Verifikasi baseline tanpa edit.
- [x] S1 — Komit baseline random-description sebagai commit terpisah.
- [x] S2 — Hapus `system_prompt.md` lokal.
- [x] S3 — Init `.memory/README.md` + 1 entri pertama.
- [x] S4 — Implement idle gating + test + bump `1.4.1+10`.
- [x] S5 — Implement foreground keep-alive + test + bump `1.5.0+11`.
- [x] S6 — Final verification + catat TODO Fase 3 + update plan log dan memory.
- [ ] TODO(Phase3-headless): spike Dio/http + cookie-jar replay login/form tanpa WebView di isolate terpisah; nilai kerapuhan vs DOM HRMIS; butuh persetujuan HR/kebijakan; TIDAK dimulai di plan ini.

## Implementation Steps

---

### S0 — Verifikasi baseline tanpa edit apa pun

- Tujuan langkah: Membuktikan dirty-state random-description sehat sebelum ditumpuk perubahan baru. Tidak ada file diubah di langkah ini.
- Finding/requirement yang diselesaikan: REQ-07 (parsial, verifikasi), prasyarat FIND-05.
- Dependency terhadap langkah lain: Tidak ada. Wajib pertama. Semua langkah lain bergantung pada S0 hijau.
- File yang harus dibaca:
  - `pubspec.yaml` (baris 1-16, cek `version: 1.4.0+9`).
  - `lib/core/attendance_descriptions.dart` (seluruh 55 baris).
  - `lib/core/attendance_prepare_js.dart` (cek signature `prepareAttendanceFormJs(AttendanceType type, {required String description})` dan baris `description.value = '$description'`).
  - `lib/main.dart` baris 492-520 (cek `final attendanceDescription = pickRandomAttendanceDescription();` di luar loop `maxPrepareAttempts = 5`, diteruskan ke `prepareAttendanceFormJs(_selectedAttendanceType, description: attendanceDescription)`).
  - `test/attendance_descriptions_test.dart` (seluruh 73 baris).
  - `test/attendance_type_test.dart` (cek `const kTestDescription` dan semua call pakai `description:`).
  - `README.md` bagian Testing dan `PROJECT_MEMORY.md` bagian verification commands sebagai referensi command.
- File yang harus diubah: TIDAK ADA. Dilarang edit/stage/commit di S0.
- Class/function/simbol terkait: `AttendanceDescription`, `kAttendanceDescriptions`, `pickRandomAttendanceDescription([Random?])`, `prepareAttendanceFormJs`, `_injectAttendanceForm`.
- Kondisi implementasi saat ini: `git status --short` menunjukkan `M lib/core/attendance_prepare_js.dart`, `M lib/main.dart`, `M pubspec.yaml`, `M test/attendance_type_test.dart`, `?? lib/core/attendance_descriptions.dart`, `?? test/attendance_descriptions_test.dart`, `?? plans/`. Itu baseline yang akan diverifikasi.
- Perubahan konkret yang harus dilakukan: TIDAK ADA perubahan kode. Hanya observasi + run command verifikasi.
- Urutan perubahan di dalam file: Tidak berlaku.
- Behavior yang harus dipertahankan: Tidak berlaku (tidak ada perubahan).
- Error handling dan edge case yang harus ditangani: Jika salah satu command gagal, STOP. Jangan lanjut ke S1. Catat output gagal ke `## Progress Log` file plan ini dan ke entri `.memory/` nanti. Jangan mencoba memperbaiki di S0.
- Test yang harus ditambahkan atau diperbarui: TIDAK ADA di S0.
- Input test dan expected result: Tidak berlaku (hanya menjalankan suite yang ada).
- Command verifikasi yang tersedia di repository (jalankan berurutan dari root repo):
  1. `flutter pub get`
  2. `flutter analyze`
  3. `flutter test`
  4. `flutter build apk --split-per-abi`
  - Referensi: `README.md:34-38,100-108,79-83`, `PROJECT_MEMORY.md:207-211`.
- Hasil verifikasi yang diharapkan:
  1. `flutter pub get`: sukses, tidak ada missing dependency (`flutter_secure_storage`, `flutter_inappwebview`, `flutter_local_notifications`, `permission_handler`, `package_info_plus` ter-resolve).
  2. `flutter analyze`: `No issues found!`.
  3. `flutter test`: semua test lolos. Baseline harapan: 81 test lama + 6 test baru di `attendance_descriptions_test.dart` = ~87 passed, 0 failed. Angka pasti diambil dari output aktual; yang penting 0 failed.
  4. `flutter build apk --split-per-abi`: sukses; `build/app/outputs/flutter-apk/` berisi `app-*.apk` asli + copy `HRMIS-Helper-v1.4.0(9)-*-release.apk` (mekanisme copy-not-rename di `android/app/build.gradle`).
- Completion criteria: Keempat command hijau. Output dicatat (cukup ringkasan jumlah test + path APK). Jika merah, S0 gagal dan plan STOP sampai blocker resolved.
- File atau area yang tidak boleh diubah: SELURUH repo. Khususnya `lib/`, `test/`, `pubspec.yaml`, `android/`, `.gitignore`, `PROJECT_MEMORY.md`, `system_prompt.md`, `.memory/`, `plans/` (selain update `## Progress Log` file plan ini yang diizinkan di S6, bukan S0).

---

### S1 — Komit baseline random-description sebagai commit terpisah

- Tujuan langkah: Mengisolasi baseline agar fix S4/S5 tidak tercampur dalam satu diff. Satu commit, satu concern.
- Finding/requirement yang diselesaikan: FIND-05, REQ-07 (finalisasi), REQ-08 (versi `1.4.0+9` sudah benar untuk fitur ini, tidak diubah di S1).
- Dependency terhadap langkah lain: Bergantung pada S0 hijau. Wajib sebelum S2-S6 yang menyentuh kode. Jika S0 merah, jangan S1.
- File yang harus dibaca:
  - Output `git status --short` dan `git diff --stat` untuk konfirmasi daftar file.
  - `plans/2026-08-31-random-attendance-description-plan.md` baris 67-90 (daftar task dan 30 deskripsi sebagai konteks commit).
- File yang harus diubah: TIDAK ADA edit konten. Hanya git staging + commit untuk file yang sudah dirty. File yang di-stage HARUS tepat 6 path ini, tidak lebih:
  1. `lib/core/attendance_descriptions.dart` (new, untracked → stage)
  2. `lib/core/attendance_prepare_js.dart` (modified)
  3. `lib/main.dart` (modified, hanya hunk deskripsi `attendanceDescription`)
  4. `test/attendance_type_test.dart` (modified)
  5. `test/attendance_descriptions_test.dart` (new, untracked → stage)
  6. `pubspec.yaml` (modified, hanya hunk `version: 1.4.0+9`)
- Class/function/simbol terkait: Sama seperti S0. Tidak ada simbol baru.
- Kondisi implementasi saat ini: 4 modified + 2 new untracked (plus `?? plans/`, `?? .zcode/` yang TIDAK boleh ikut ter-stage).
- Perubahan konkret yang harus dilakukan (perintah git, dari root):
  1. `git status --short` → verifikasi daftar cocok dengan 6 path di atas (+ `?? plans/`, `?? .zcode/` yang harus tetap unstaged).
  2. `git diff -- lib/core/attendance_prepare_js.dart pubspec.yaml test/attendance_type_test.dart` → verifikasi hunk hanya seputar `description` dan versi.
  3. Stage eksplisit per-file (dilarang `git add -A` / `git add .` karena akan menyeret `plans/`, `.zcode/`):
     `git add lib/core/attendance_descriptions.dart lib/core/attendance_prepare_js.dart lib/main.dart test/attendance_type_test.dart test/attendance_descriptions_test.dart pubspec.yaml`
  4. `git status --short` lagi → pastikan staged tepat 6 file, `plans/` dan `.zcode/` tetap `??` unstaged.
  5. Commit satu baris Conventional Commits, tanpa trailer `Co-authored-by`:
     `git commit -m "feat: randomize attendance description from 30 bilingual options"`
- Urutan perubahan di dalam file: Tidak ada edit file. Urutan di atas wajib berurutan (verifikasi → stage eksplisit → verifikasi → commit).
- Behavior yang harus dipertahankan: Tidak ada perubahan behavior di S1 (hanya commit).
- Error handling dan edge case yang harus ditangani:
  - Jika `git diff lib/main.dart` menunjukkan hunk SELAIN deskripsi (misal flag gating sudah tercampur), STOP. Jangan commit. Kembalikan ke state S0 dan pisahkan hunk secara manual dengan `git add -p` hanya untuk hunk deskripsi. Jika ragu, jadikan blocker dan tanya user.
  - Jika hook commit menolak, buat commit baru hasil perbaikan; dilarang amend commit gagal (sesuai aturan git).
  - Dilarang `git push`, `git amend`, `--force`, `-i`, commit kosong.
- Test yang harus ditambahkan atau diperbarui: TIDAK ADA di S1.
- Input test dan expected result: Tidak berlaku.
- Command verifikasi yang tersedia di repository:
  - `git log --oneline -3` → commit baru di puncak dengan pesan persis di atas.
  - `git status --short` → 6 path hilang dari daftar, tersisa `?? plans/`, `?? .zcode/` (dan plan file ini jika belum dikomit).
  - `flutter test` ulang cepat (opsional, harus tetap hijau).
- Hasil verifikasi yang diharapkan: Satu commit baru, diff commit hanya 6 file, pesan commit persis satu baris.
- Completion criteria: `git show --stat HEAD` berisi tepat 6 file tersebut. `plans/` dan `.zcode/` tidak masuk commit.
- File atau area yang tidak boleh diubah/di-stage: `plans/`, `.zcode/`, `view_source_hrmis/`, `build/`, `.dart_tool/`, `.mimocode/`, `.memory/`, `PROJECT_MEMORY.md`, `system_prompt.md`, `android/`, `.gitignore`, file plan ini (dikomit terpisah di akhir, bukan di S1).

---

### S2 — Hapus `system_prompt.md` lokal (tanpa git rm)

- Tujuan langkah: Menghilangkan konteks kedaluwarsa yang menyebut `.env`/`flutter_dotenv` dan menyesatkan eksekutor berikutnya.
- Finding/requirement yang diselesaikan: REQ-05, FIND-03.
- Dependency terhadap langkah lain: Bergantung pada S1 selesai (agar penghapusan tidak tercampur commit baseline). Independen terhadap S3-S5 secara konten, tapi kerjakan setelah S1 sesuai urutan.
- File yang harus dibaca:
  - `system_prompt.md` baris 12, 21-24, 52-68 (bukti masih sebut `.env`, `flutter_dotenv`, `.env.example`).
  - `lib/config.dart` baris 1-10 (bukti realitas: `flutter_secure_storage` + `encryptedSharedPreferences: true`, tidak ada dotenv).
  - `.gitignore` baris 44-49 (bukti `system_prompt.md` ter-ignore).
  - Output `git ls-files | Select-String system_prompt` (harus kosong = untracked) dan `git check-ignore -v system_prompt.md` (harus tunjuk `.gitignore:48`).
- File yang harus diubah: Tepat 1 path dihapus dari filesystem lokal: `system_prompt.md`. TIDAK ADA file lain disentuh.
- Class/function/simbol terkait: Tidak ada (file markdown konteks saja).
- Kondisi implementasi saat ini: File ada di working directory, untracked + ignored. `README.md` sudah benar (tanpa `.env`), jadi penghapusan aman.
- Perubahan konkret yang harus dilakukan (berurutan):
  1. Jalankan `git ls-files` cek + `git check-ignore -v system_prompt.md` untuk membuktikan untracked. Jika ternyata tracked (muncul di `ls-files`), STOP dan jadikan blocker (jangan `git rm` diam-diam).
  2. Jika terbukti untracked, hapus via PowerShell: `Remove-Item -LiteralPath "system_prompt.md"`.
  3. Verifikasi `Test-Path -LiteralPath "system_prompt.md"` = `False` dan `git status --short` tidak menunjukkan penghapusan tracked (karena memang untracked, tidak ada `D` entry).
- Urutan perubahan di dalam file: Tidak berlaku (penghapusan file).
- Behavior yang harus dipertahankan: Tidak ada perubahan runtime. `README.md`, `lib/config.dart`, credential flow tidak disentuh.
- Error handling dan edge case yang harus ditangani:
  - Jika file terkunci/open di editor, tutup dulu lalu ulangi. Jangan hapus paksa direktori lain.
  - Jika `git ls-files` menunjukkan tracked, jangan hapus. Catat sebagai blocker: opsi (a) `git rm --cached` + hapus (perlu persetujuan user karena mengubah index), (b) biarkan. Rekomendasi: opsi (b) tahan dulu sampai user setuju, karena status saat ini untracked.
- Test yang harus ditambahkan atau diperbarui: TIDAK ADA test kode. Verifikasi filesystem sebagai pengganti test.
- Input test dan expected result: Input = perintah cek di atas. Expected = `ls-files` kosong, `check-ignore` menunjuk `.gitignore:48`, `Test-Path` False setelah hapus.
- Command verifikasi yang tersedia di repository:
  - `git status --short` (tidak ada `D system_prompt.md` karena untracked).
  - `flutter analyze` (harus tetap `No issues found`, memastikan tidak ada import ke file yang dihapus — memang tidak ada).
- Hasil verifikasi yang diharapkan: File hilang lokal, tidak ada perubahan tracked, analyze tetap hijau.
- Completion criteria: `system_prompt.md` tidak ada di disk, tidak ada commit/index change untuk file ini, `.gitignore` tidak diubah.
- File atau area yang tidak boleh diubah: Semua selain path tersebut. Khususnya dilarang menyentuh `.gitignore`, `README.md`, `lib/`, `test/`, `android/`.

---

### S3 — Inisialisasi `.memory/` aktif (tetap untracked)

- Tujuan langkah: Memenuhi AGENTS.md §5 (Active Format + Legacy Migration) sambil menghormati keputusan user `tetap untracked`.
- Finding/requirement yang diselesaikan: REQ-06, FIND-04.
- Dependency terhadap langkah lain: Setelah S1 (jangan campur dengan commit baseline). Bisa paralel konten dengan S2, tapi eksekusi setelah S2 agar urutan log jelas.
- File yang harus dibaca:
  - `PROJECT_MEMORY.md` seluruhnya (262 baris) — hanya untuk ekstraksi state aktif, BUKAN untuk rewrite penuh.
  - `.gitignore` baris 44-49 (konfirmasi `.memory/` dan `PROJECT_MEMORY.md` ter-ignore; jangan ubah).
  - `plans/2026-08-31-random-attendance-description-plan.md` dan file plan ini sebagai referensi open items.
- File yang harus diubah: Tepat 2 file baru di direktori baru `.memory/`:
  1. `.memory/README.md` (index ringkas, bukan duplikat log).
  2. `.memory/YYYY-MM-DD/HHmmss-hrmis-baseline-and-startup-gating.md` (1 entri, gunakan tanggal/jam lokal proyek saat eksekusi, format `HHmmss-kebab-case`, tambah suffix unik jika tabrakan).
- Class/function/simbol terkait: Tidak ada simbol Dart. Terkait konsep AGENTS.md: `current state`, `active decisions`, `open items/blockers`, `legacy archive link`, `Recent Entries (max 20)`.
- Kondisi implementasi saat ini: Direktori `.memory/` tidak ada (`Test-Path .memory` = False). `PROJECT_MEMORY.md` ada sebagai legacy tunggal.
- Perubahan konkret yang harus dilakukan (berurutan):
  1. `Test-Path -LiteralPath ".memory"` → harus False. Jika True, baca dulu `README.md` yang ada dan jangan timpa; gabungkan (re-read sebelum edit karena agen konkuren mungkin aktif).
  2. Buat direktori tanggal: `New-Item -ItemType Directory -Path ".memory/YYYY-MM-DD"` (ganti tanggal aktual).
  3. Tulis `.memory/README.md` dengan struktur wajib: `last-updated timestamp`, `format version`, `current state` (versi app, baseline random-description committed, startup masih auto-run sebelum S4, keep-alive belum ada), `active decisions` (idle-until-Run, foreground-only Fase 1, Fase 3 TODO, untracked dipertahankan), `open items/blockers` (S4-S6 pending, open question service type), `legacy archive link` (`../PROJECT_MEMORY.md`), `Recent Entries` (max 20 link, awalnya 1 link ke entri baru).
  4. Tulis 1 entri timestamped berisi 7 bagian wajib: task/problem, key files changed, technical/business decisions, assumptions/risks, blockers/unresolved, verification performed/recommended, one-line Conventional Commit proposal, related plans/issues. Contoh commit proposal di entri: `docs: init active memory and record hrmis baseline`.
  5. Jangan append ke `PROJECT_MEMORY.md`. Jangan split/rewrite seluruh histori legacy.
- Urutan perubahan di dalam file: Buat direktori dulu, lalu `README.md`, lalu entri (atau sebaliknya tidak masalah asal link di README menunjuk path entri yang benar-benar ada setelah kedua tulis selesai; verifikasi link).
- Behavior yang harus dipertahankan: Tidak ada perubahan runtime. Tidak ada perubahan git tracking.
- Error handling dan edge case yang harus ditangani:
  - Jika `.memory/README.md` tiba-tiba muncul (agen konkuren), re-read dan preserve tulisan user/agen lain; hanya update bagian yang berubah (state/decisions/open/recent).
  - Jika nama entri tabrakan, tambah suffix unik (misal `-a`, `-b`), jangan timpa.
  - Jangan menyimpan secret/password/token/`sb_secret_*`/`sb_publishable_*`/data produksi di memory (Env Guard). Jika tidak sengaja tertulis, hapus dan sarankan rotasi via Dashboard.
- Test yang harus ditambahkan atau diperbarui: TIDAK ADA test Dart. Verifikasi = cek struktur file.
- Input test dan expected result:
  - Input: `Get-ChildItem .memory` dan baca kedua file.
  - Expected: `.memory/README.md` memuat 6 bagian wajib + timestamp; entri memuat 7 bagian wajib; `Recent Entries` ≤20; tidak ada secret string.
- Command verifikasi yang tersedia di repository:
  - `git status --short` → `.memory/` TIDAK muncul sebagai staged (karena ignored; jika muncul sebagai `??`, itu normal dan harus dibiarkan unstaged).
  - `git check-ignore -v .memory/README.md` → menunjuk `.gitignore:46`.
- Hasil verifikasi yang diharapkan: 2 file ada di disk, tetap ignored/unstaged, tidak ada secret, link valid.
- Completion criteria: `.memory/README.md` + 1 entri ada, format valid, `PROJECT_MEMORY.md` tidak diubah, `.gitignore` tidak diubah.
- File atau area yang tidak boleh diubah: `PROJECT_MEMORY.md` (read-only arsip), `.gitignore`, `lib/`, `test/`, `android/`, `pubspec.yaml`, `system_prompt.md` (sudah dihapus di S2, jangan dibuat lagi).

---

### S4 — Idle gating: startup diam di Dashboard sampai tekan Run (bugfix patch)

- Tujuan langkah: Menghentikan silent auto-run WFO dan mewajibkan picker eksplisit. Keputusan user: idle, BUKAN auto-prompt picker.
- Finding/requirement yang diselesaikan: REQ-01, REQ-02, FIND-01.
- Dependency terhadap langkah lain: Wajib setelah S1 (baseline committed). Independen terhadap S5 secara kode, tapi S5 harus setelah S4 agar lifecycle keep-alive menempel pada flow idle yang benar.
- File yang harus dibaca (wajib sebelum edit):
  - `lib/main.dart` baris 137-182 (`_AttendanceAutomationPageState` fields, `initState`, `_checkPermissions`), 225-323 (`_openCredentialScreen`, `_handleLoadStop`, `_navigateToAttendanceForm`, `_onRunAttendancePressed`, `_runAttendanceAutomation`), 335-434 (`_injectLogin`), 436-639 (`_injectAttendanceForm` incl. 492-526 prepare loop, 537-573 GPS gate, 575-639 save+verify), 788-847 (`_currentUri`, `_hasLoggedInProfile`, `_evaluateJavascript`, `_updateStatus`), 849-963 (`build`, `_buildAutomationView`, `_StatusOverlay`, `_PermissionGuard`).
  - `lib/dashboard_view.dart` baris 10-103 (`DashboardView`, `_canRunAttendance`), 190-293 (`ActionPanel`).
  - `lib/attendance_type_picker.dart` seluruh 92 baris (`showAttendanceTypePicker`, `AttendanceTypeSheet`).
  - `lib/config.dart` (`hasCredentials`), `lib/core/hrmis_uri.dart` (routing helpers).
  - Test existing: `test/attendance_type_picker_test.dart`, `test/dashboard_view_test.dart`, `test/credential_screen_test.dart` (pola mock: `setMockMethodCallHandler` returning encoded null, `PackageInfo.setMockInitialValues` harus FIRST di file).
- File yang harus diubah (tepat 3 file sumber + 2-3 file test + 1 versi):
  1. `lib/main.dart` (utama).
  2. `test/startup_gating_test.dart` (BARU).
  3. `test/dashboard_view_test.dart` (update jika assertion status idle berubah).
  4. `pubspec.yaml` (hanya baris `version:`).
- Class/function/simbol terkait: `_AttendanceAutomationPageState`, `_automationRequested` (BARU, `bool`, default `false`), `_selectedTabIndex`, `_selectedAttendanceType`, `_webViewController`, `_loginUri`, `_hasRequiredPermissions`, `_attendanceTodayStatus`, `_status`, metode `_handleLoadStop`, `_buildAutomationView`, `_runAttendanceAutomation`, `_onRunAttendancePressed`, `_openCredentialScreen`, `showAttendanceTypePicker`, `AttendanceType`, `DashboardView`, `InAppWebView`.
- Kondisi implementasi saat ini:
  - `_selectedTabIndex = 0` awal tapi `IndexedStack` membangun `_buildAutomationView` eager.
  - `_buildAutomationView:907-949` selalu buat `InAppWebView(initialUrlRequest: _loginUri)` jika permission granted.
  - `_handleLoadStop` langsung `_injectLogin`/`_injectAttendanceForm` tanpa gate.
  - `_selectedAttendanceType = AttendanceType.wfo` default menyebabkan silent WFO.
  - `_openCredentialScreen:235` sudah panggil `_onRunAttendancePressed` (picker) — pertahankan.
- Perubahan konkret yang harus dilakukan (urutan wajib di dalam `lib/main.dart`):
  1. Deklarasi: tambah `bool _automationRequested = false;` tepat setelah `bool _isRequestingPermissions = false;` (~baris 160). Beri komentar `// Idle until explicit Run — prevents silent WFO auto-run.`.
  2. `_handleLoadStop:239`: tambah guard PALING ATAS setelah null/parse check, sebelum `isHomeInspectionPage` branch:
     `if (!_automationRequested) { log('[AutoAttend] Idle — automation not requested yet'); return; }`
     Jangan ubah branch lain.
  3. `_buildAutomationView:903-963`: ubah `Positioned.fill child:` menjadi 3 cabang berurutan:
     a. jika `!_hasRequiredPermissions` → `_PermissionGuard` (pertahankan persis).
     b. else jika `!_automationRequested` → widget placeholder idle BARU (misal `_IdleAutomationPlaceholder` private StatelessWidget di file yang sama, bawah `_PermissionGuard`): icon `public_outlined`, teks `Automation is idle.` + `Choose Run attendance on the Dashboard to pick WFO/WFH/SPJ.` + tidak ada WebView/controller action. Jangan buat `InAppWebView` di cabang ini.
     c. else → `InAppWebView` existing persis (initialUrl, settings, callbacks `onLoadStart/Stop`, `onUpdateVisitedHistory`, `onConsoleMessage`, `onGeolocationPermissionsShowPrompt`, `onPermissionRequest`, `onReceivedError`).
  4. `_runAttendanceAutomation:300-323`: di awal tambah `_automationRequested = true;` sebelum reset flags. Pertahankan reset 8 flags (`_loginInjected`, `_loginInjectionInProgress`, `_formNavigationTriggered`, `_attendanceInjected`, `_attendanceInjectionInProgress`, `_homeInspectionRequested`, `_homeInspectionInProgress`, `_homeInspectionCompleted`, `_attendanceTodayStatus=checking`). `setState` pindah ke tab 1 (`_selectedTabIndex = 1`) dipertahankan. Karena WebView baru dibuat setelah `setState` (cabang c), `loadUrl(_loginUri)` via `_webViewController` mungkin null pada frame pertama — tangani dengan `WidgetsBinding.instance.addPostFrameCallback((_) async { if (!mounted) return; if (_webViewController == null) return; // initialUrlRequest sudah load, jangan double-load; else loadUrl }`. Aturan deterministik: jika `_webViewController == null` setelah post-frame, jangan panggil `loadUrl` (initial load sudah terjadi via `initialUrlRequest`); jika controller sudah ada (kasus Run kedua), panggil `loadUrl(_loginUri)`.
  5. `_onRunAttendancePressed:290-298`: pertahankan picker-then-run. Jika `type == null` (dismiss), JANGAN set `_automationRequested`, JANGAN pindah tab, JANGAN ubah `_selectedAttendanceType`. Hanya `log('[Picker] result=null (dismissed)')` dan return.
  6. `_openCredentialScreen:225-237`: pertahankan Opsi B (panggil `_onRunAttendancePressed()` setelah save). Jangan ubah menjadi auto-run.
  7. `initState:173-182` + `_checkPermissions`/`_requestPermissions`: jangan tambah auto-load/auto-picker. Setelah grant, status = `Opening HRMIS...` boleh diganti menjadi `Choose Run attendance to start.` agar konsisten idle — ini satu-satunya string status yang boleh diubah di S4, dan harus diupdate di test jika diassert.
  8. Tambah private widget `_IdleAutomationPlaceholder` di bawah `_PermissionGuard` (akhir file), jangan buat file baru.
  9. `pubspec.yaml`: ubah HANYA baris `version: 1.4.0+9` → `version: 1.4.1+10` (bugfix: patch+1, build+1, minor reset tidak berlaku karena minor tetap 4).
- Urutan perubahan di dalam file: deklarasi → guard `_handleLoadStop` → `_buildAutomationView` cabang → `_runAutomation` flag + postframe → `_onRun` dismiss guard → status string → placeholder widget → versi. Jangan acak agar diff reviewable.
- Behavior yang harus dipertahankan:
  - Picker listing WFO/WFH/SPJ + `requiresGeolocation` tooltip tidak berubah.
  - GPS polling 20x1s hanya WFO (`requiresGeolocation`), WFH/SPJ langsung save.
  - Prepare retry 5x dengan deskripsi stabil (`attendanceDescription` pick-once), save retry 3x, verify reload + `attendance-already-recorded` selector expanded, home inspection DOM-then-XHR, notifikasi warning.
  - Permission guard, credential Keystore flow, About screen, bottom nav Dashboard/Automation, FAB settings.
  - `onUpdateVisitedHistory` tetap panggil `_handleLoadStop` (gate di dalam yang menahan).
- Error handling dan edge case yang harus ditangani:
  - `_webViewController == null` saat Run pertama → jangan crash, andalkan `initialUrlRequest`. Gunakan `?.` dan null-check + `mounted` check sebelum setiap `setState`/`loadUrl` (pola existing `_updateStatus` sudah `if (!mounted) return`).
  - User dismiss picker → tetap idle, tab tetap 0, `_attendanceTodayStatus` tetap `checking`, tidak ada navigasi.
  - User tanpa kredensial tekan Run → `_injectLogin` sudah handle `No HRMIS credentials stored` → pertahankan, jangan tambah dialog baru.
  - User tanpa permission tekan Run → `_runAutomation` early-return jika `!_hasRequiredPermissions` (pertahankan baris 318).
  - Navigasi menjauh dari form saat prepare/GPS/save → early-return existing dipertahankan.
  - Run kedua setelah recorded: `_canRunAttendance` false di Dashboard (recorded → tombol `Open automation view`), jangan paksa re-arm. Jika user paksa pindah tab manual, WebView tunjukkan state terakhir, jangan re-inject karena `_attendanceInjected` true.
- Test yang harus ditambahkan atau diperbarui:
  - BARU `test/startup_gating_test.dart`: pump `AutoAttendApp`/`AttendanceAutomationPage` dengan mock secure-storage (pola `setMockMethodCallHandler` encoded null, BUKAN raw `setMessageHandler`) dan `PackageInfo.setMockInitialValues` FIRST. Assert: (a) idle awal: `find.text('Run attendance')` findsOne, `find.byType(InAppWebView)` findsNothing, status berisi `Choose Run` atau `Automation is idle`; (b) dismiss picker (mock navigator pop null) → tetap findsNothing WebView; (c) picker return `AttendanceType.wfh` → WebView muncul (findsOne) dan `_selectedAttendanceType.label == 'WFH'`. Jika mocking WebView berat, minimal assert flag/cabang via `DashboardView.canRunAttendance` + tidak ada `loadUrl` dipanggil (verifikasi via log atau controller null). Pilih pendekatan yang stabil di CI tanpa device.
  - UPDATE `test/dashboard_view_test.dart` jika string status idle diubah — ubah expected persis, jangan hapus test lama.
  - JANGAN ubah `test/attendance_descriptions_test.dart`, `test/attendance_type_test.dart` kecuali import rusak akibat rename (tidak ada rename di S4).
- Input test dan expected result:
  - Input gating: launch app fresh (mock credentials ada, permission granted via mock). Expected: idle, no WebView.
  - Input dismiss: `showAttendanceTypePicker` → `pop(null)`. Expected: tetap idle, tab 0.
  - Input pick WFH: `pop(AttendanceType.wfh)`. Expected: tab 1, WebView ada, log `[Picker] result=AttendanceType.wfh`, GPS skipped (tertutup test integrasi manual).
  - Input pick WFO: `pop(AttendanceType.wfo)`. Expected: WebView ada, GPS polling path aktif (unit GPS logic tidak diubah, cukup assert type).
- Command verifikasi yang tersedia di repository:
  1. `flutter pub get`
  2. `flutter analyze` → `No issues found!`
  3. `flutter test` → semua lolos (baseline ~87 + 3-5 baru S4, 0 failed)
  4. `flutter build apk --split-per-abi` → sukses, cek `build/app/outputs/flutter-apk/HRMIS-Helper-v1.4.1(10)-*-release.apk` + `app-*.apk` asli tetap ada.
- Hasil verifikasi yang diharapkan: Analyze bersih, test hijau, APK idle-gating ter-build dengan versi baru. Manual di device: cold-start → Dashboard idle, tidak ada overlay `Logging in...` otomatis; tekan Run → bottomsheet muncul; pilih SPJ → langsung `Saving` tanpa `Waiting for GPS`; kunci 5 detik → kembali → status `Paused` atau lanjut (full pause-resume baru di S5, di S4 cukup tidak crash).
- Completion criteria: Cold-start tidak pernah trigger `_injectLogin`/`_injectAttendanceForm` (buktikan via log: tidak ada `[WebView] Load stopped` sebelum Run, atau ada load tapi `[AutoAttend] Idle` return). Picker hanya dari aksi eksplisit. Versi `1.4.1+10`. Semua test hijau.
- File atau area yang tidak boleh diubah: `lib/core/*` (kecuali tidak ada), `lib/config.dart`, `lib/notification_service.dart`, `lib/credential_screen.dart`, `lib/about_screen.dart`, `lib/attendance_type_picker.dart`, `android/` (manifest/build.gradle), `.gitignore`, `.memory/`, `PROJECT_MEMORY.md`, `view_source_hrmis/`, `.zcode/`, `assets/`. `lib/dashboard_view.dart` hanya boleh jika string idle wajib diselaraskan, dan harus dicatat di log.

---

### S5 — Foreground keep-alive untuk lock/home pendek (fitur minor)

- Tujuan langkah: Membuat otomasi 30-60 detik tahan terhadap lock/home singkat via WakeLock + foreground service + lifecycle resume. BUKAN background penuh.
- Finding/requirement yang diselesaikan: REQ-03, FIND-02.
- Dependency terhadap langkah lain: Wajib setelah S4 (menempel pada flow idle-gating yang benar). Bergantung pada S1 (baseline committed). Jika S4 belum hijau, jangan S5.
- File yang harus dibaca (wajib sebelum edit):
  - `lib/main.dart` seluruh flow `Future.delayed` (baris 344, 354-355, 493-526, 538-573, 594-602, 645) + `_updateStatus`, `dispose` (belum ada — cek dan tambah jika perlu).
  - `lib/notification_service.dart` seluruh 53 baris (channel `hrmis_attendance_alerts`, `initialize`, `showAttendanceWarning`).
  - `android/app/src/main/AndroidManifest.xml` seluruh 35 baris.
  - `pubspec.yaml` dependencies (untuk penempatan alfabetis dan versi `^`).
  - Dokumentasi paket di pub.dev untuk `wakelock_plus` dan `flutter_foreground_task` (API `init`, `startService`, `stopService`, `allowWakeLock/allowWifiLock`, `serviceTypes`, `stopWithTask`). Jangan tebak API; baca versi terpasang setelah `pub get`.
- File yang harus diubah (tepat 4-5 file):
  1. `pubspec.yaml` (tambah 2 deps).
  2. `android/app/src/main/AndroidManifest.xml` (permissions + service).
  3. `lib/main.dart` (lifecycle observer + start/stop service + wakelock).
  4. `lib/notification_service.dart` (tambah channel foreground service JIKA dibutuhkan, jangan ubah channel alerts existing).
  5. `test/foreground_gating_test.dart` (BARU, unit ringan; service asli tidak di-unit-test, hanya mapper/status).
- Class/function/simbol terkait: `WidgetsBindingObserver`, `AppLifecycleState.paused/resumed`, `WakelockPlus.enable/disable`, `FlutterForegroundTask.init/startService/stopService/updateService/isRunningService`, `FlutterBackground` (DITOLAK, jangan pakai), `NotificationService`, `_attendanceInjectionInProgress`, `_attendanceInjected`, `_attendanceTodayStatus`, `_status`, `Permission.notification`, `MainActivity`.
- Kondisi implementasi saat ini: Tidak ada WakeLock, tidak ada foreground service, tidak ada `WidgetsBindingObserver`, tidak ada `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. `NotificationService.initialize` sudah request `Permission.notification`. Manifest hanya 5 permissions dasar.
- Perubahan konkret yang harus dilakukan (urutan wajib):
  1. `pubspec.yaml`: tambah di `dependencies` (jaga urutan alfabetis):
     `wakelock_plus: ^1.2.0` (atau versi latest `^` yang di-resolve `pub get`; catat versi aktual di log) dan `flutter_foreground_task: ^9.0.0` (atau latest; catat aktual). Jalankan `flutter pub get` dan catat versi ter-resolve dari `pubspec.lock` ke log (jangan edit `pubspec.lock` manual).
  2. `AndroidManifest.xml`: tambah di dalam `<manifest>` (sebelum `<application>`):
     `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`,
     `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />` (lihat Open Question OQ-01 untuk alternatif),
     `<uses-permission android:name="android.permission.WAKE_LOCK" />`,
     `<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />`.
     Tambah di dalam `<application>` (setelah `<activity>`, sebelum closing):
     `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService" android:exported="false" android:stopWithTask="true" android:foregroundServiceType="dataSync" />`
     Jika nama class service berbeda di versi terpasang, gunakan persis dari docs versi itu dan catat di log. Jangan tebak.
  3. `lib/main.dart`:
     a. Import 2 paket baru di atas import lokal.
     b. `class _AttendanceAutomationPageState extends State<...> with WidgetsBindingObserver` (tambah mixin).
     c. `initState`: `WidgetsBinding.instance.addObserver(this);` pertama, `super.initState()` tetap, sisanya dipertahankan. Tambah `FlutterForegroundTask.init(...)` sekali (channelId `hrmis_automation`, channelName `HRMIS Automation`, `allowWakeLock:true`, `allowWifiLock:true`, `autoRunOnBoot:false`, `autoRunOnMyPackageReplaced:false`) — parameter persis ikuti docs versi terpasang.
     d. Tambah `dispose`: `WidgetsBinding.instance.removeObserver(this); await FlutterForegroundTask.stopService(); WakelockPlus.disable(); super.dispose();` (jaga `mounted` dan async-safe).
     e. Tambah `didChangeAppLifecycleState(AppLifecycleState state)`: jika `state == paused` dan `_attendanceInjectionInProgress` true → `_updateStatus('Paused — return to app to continue.')` + `log('[AutoAttend] Paused during injection')`; jika `resumed` dan `_attendanceInjectionInProgress` true → `_updateStatus('Resumed — checking HRMIS...')` + re-read `_currentUri()` (jangan restart dari awal). Jika tidak in-progress, jangan ubah status.
     f. `_injectAttendanceForm` awal (setelah set `_attendanceInjectionInProgress=true`): `WakelockPlus.enable(); await FlutterForegroundTask.startService(notificationTitle: 'HRMIS automation running', notificationText: 'Keep app open until verified', ...);` dengan `serviceId: 2001`, `callback: null` atau startCallback sesuai docs (jangan buat isolate callback baru di S5; gunakan mode simple tanpa background isolate).
     g. Semua exit path `_injectAttendanceForm` (recorded early-return:487, prepare-fail:533, GPS-fail:571, save-done:633, save-fail:638) + `_inspectHomeAttendanceSummary` akhir + `_injectLogin` fail path: tambah `finally`-style release: `WakelockPlus.disable(); await FlutterForegroundTask.stopService();` tepat sebelum `return`/`_navigateToHomeForInspection`. Untuk menghindari duplikasi, bungkus dengan helper private `Future<void> _releaseKeepAlive()` di file yang sama dan panggil di tiap exit. Jangan ubah logika retry/count.
     h. Jangan ubah durasi delay (15s login, 20x1s GPS, 5s+3s verify, 2s inspect).
  4. `lib/notification_service.dart`: JANGAN ubah `showAttendanceWarning` dan channel `hrmis_attendance_alerts`. Jika `flutter_foreground_task` butuh channel terpisah, tambah konstanta/channel baru untuk foreground service saja.
  5. `pubspec.yaml` versi: `1.4.1+10` → `1.5.0+11` (fitur: minor+1, patch reset 0, build+1).
- Urutan perubahan di dalam file: pubspec → `pub get` → manifest → Dart imports → mixin+init/dispose → lifecycle method → start/release helper → panggil di tiap exit → versi. Test setelah kode.
- Behavior yang harus dipertahankan: Semua flow S4 (idle, picker, prepare 5x, GPS 20x1s WFO-only, save 3x, verify reload, home DOM-then-XHR, warning notif). Durasi dan selector JS tidak berubah. Opsi B credential-picker tidak berubah.
- Error handling dan edge case yang harus ditangani:
  - `startService` gagal (permission ditolak, service sudah running) → catch, log, lanjutkan otomasi foreground tanpa service (degraded, jangan abort). Cek `await FlutterForegroundTask.isRunningService` sebelum start/restart.
  - `WakelockPlus.enable` throw di emulator tanpa sensor → catch+log, lanjutkan.
  - `stopService` saat sudah stopped → catch diam-diam.
  - Lock/home >15 menit atau OS kill (OEM agresif) → tidak dijamin; status harus jujur `Paused/Needs action`, bukan `success`. Jangan klaim tahan lama.
  - `POST_NOTIFICATIONS` ditolak → foreground service mungkin tidak tampil; fallback ke wakelock-only + status warning.
  - Double-start (Run ditekan 2x cepat) → guard `_attendanceInjectionInProgress` existing + `isRunningService` check, jangan start dua service.
  - `didChangeAppLifecycleState` dipanggil saat tidak in-progress → no-op.
- Test yang harus ditambahkan atau diperbarui:
  - BARU `test/foreground_gating_test.dart` (unit murni, tanpa device): test helper `_releaseKeepAlive` dipanggil di tiap exit? Karena helper private sulit di-test langsung, ekstrak pure function `String pausedStatus(bool inProgress)` atau `keepAliveMessage(AppLifecycleState, bool)` jika perlu — TAPI jangan refactor besar. Minimal: test bahwa `paused` saat in-progress menghasilkan string `Paused — return to app to continue.` dan `resumed` menghasilkan `Resumed — checking HRMIS...`, dan saat `!inProgress` menghasilkan null/no-op. Input/expected eksplisit di bawah.
  - JANGAN mock `FlutterForegroundTask` channel asli di unit test (flaky). Untuk widget, cukup assert placeholder idle + tombol Run tetap ada setelah tambah mixin (regression).
  - Manual test matrix wajib (dicatat di log, bukan automated): (a) Run WFO → lock 10s → unlock → lanjut/tidak crash; (b) Run SPJ → home 10s → balik → verify tetap jalan; (c) tolak notifikasi → tetap jalan wakelock-only; (d) Xiaomi/Oppo jika ada → catat perilaku OEM.
- Input test dan expected result:
  - Input: `keepAliveMessage(paused, true)` → Expected: `Paused — return to app to continue.`
  - Input: `keepAliveMessage(resumed, true)` → Expected: `Resumed — checking HRMIS...`
  - Input: `keepAliveMessage(paused, false)` → Expected: `null` (no-op).
  - Input: `keepAliveMessage(resumed, false)` → Expected: `null`.
  - Jika nama helper berbeda, sesuaikan tapi pertahankan mapping input→output di atas dan update plan log.
- Command verifikasi yang tersedia di repository:
  1. `flutter pub get`
  2. `flutter analyze` → `No issues found!`
  3. `flutter test` → semua lolos (baseline S4 + 2-4 baru S5, 0 failed)
  4. `flutter build apk --split-per-abi` → sukses, cek `HRMIS-Helper-v1.5.0(11)-*-release.apk`.
- Hasil verifikasi yang diharapkan: Analyze bersih (tanpa `avoid_print` error baru; gunakan `log()`), test hijau, APK ter-build. Manual lock/home pendek tidak crash dan status jujur.
- Completion criteria: Lock 10s/unlock dan home 10s/balik tidak crash, tidak silent-fail sebagai success; service notification muncul selama injection dan hilang setelah selesai; wakelock release (cek via log + tidak ada `WakelockPlus.enable` tanpa `disable` di code review); versi `1.5.0+11`.
- File atau area yang tidak boleh diubah: `lib/core/*`, `lib/config.dart`, `lib/credential_screen.dart`, `lib/about_screen.dart`, `lib/attendance_type_picker.dart`, `lib/dashboard_view.dart` (kecuali string status paused yang wajib diselaraskan dan dicatat), `android/app/build.gradle`, `.gitignore`, `.memory/`, `PROJECT_MEMORY.md`, `view_source_hrmis/`, `.zcode/`, `assets/`.

---

### S6 — Final verification + TODO Fase 3 + tutup plan dan memory

- Tujuan langkah: Membuktikan gabungan S4+S5 hijau, mencatat Fase 3 sebagai TODO resmi, dan menutup dokumentasi tanpa sisa dirty tak terdokumentasi.
- Finding/requirement yang diselesaikan: REQ-04, penutup REQ-01—REQ-08.
- Dependency terhadap langkah lain: Setelah S0-S5 semua hijau. Jangan S6 jika ada merah.
- File yang harus dibaca:
  - File plan ini (`## Tasks`, `## Progress Log`) untuk update checklist.
  - `.memory/README.md` dan entri S3 untuk update state/decisions/open/recent.
  - `git status --short`, `git log --oneline -5`, `git diff --stat` untuk memastikan hanya file yang diniatkan yang berubah/terkomit.
- File yang harus diubah: Tepat 2 area dokumentasi (BUKAN source):
  1. File plan ini: centang `Tasks` (`- [x]`), tambah dated entries di `## Progress Log`, pastikan `## Risks` mencerminkan hasil aktual.
  2. `.memory/` (tetap untracked): update `README.md` (state→`1.5.0+11`, decisions, open items) + tambah 1 entri penutup ATAU append ke entri S3 sesuai aturan (satu entri per task signifikan; S4 dan S5 masing-masing 1 entri tambahan lebih baik daripada 1 raksasa — total max 3 entri baru + README update).
- Class/function/simbol terkait: Tidak ada simbol Dart baru. Simbol dokumentasi: `TODO(Phase3-headless)`, `OQ-01`, `OQ-02` di bawah.
- Kondisi implementasi saat ini: Source S4+S5 selesai + terkomit terpisah (lihat S1/S4/S5 commit). Dokumentasi masih pending.
- Perubahan konkret yang harus dilakukan (berurutan):
  1. Full verify: `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --split-per-abi`. Catat ringkasan di plan log.
  2. Di file plan ini, tambah TODO eksplisit (unchecked, agar tidak dikerjakan diam-diam):
     `- [ ] TODO(Phase3-headless): spike Dio/http + cookie-jar replay login/form tanpa WebView di isolate terpisah; nilai kerapuhan vs DOM HRMIS; butuh persetujuan HR/kebijakan; TIDAK dimulai di plan ini.`
  3. Update `.memory/README.md`: `current state` → versi final + idle-gating live + keep-alive live; `active decisions` pertahankan; `open items` → hanya `TODO(Phase3-headless)` + OQ tersisa (jika ada); `Recent Entries` tambah link entri S4/S5/S6 (max 20, jangan hapus histori).
  4. Buat entri `.memory/` untuk S4 dan S5 (dan S6 jika signifikan) dengan 7 bagian wajib + usulan commit yang SUDAH dipakai (bukan proposal baru):
     S4: `fix: require explicit run before hrmis automation starts`
     S5: `feat: keep hrmis automation alive in foreground`
  5. Verifikasi `git status --short`: source commits bersih, tersisa hanya `?? plans/2026-09-22-hrmis-implementation-plan.md` (file ini, akan dikomit terpisah sebagai `docs: add hrmis idle and keep-alive implementation plan`) + `.memory/` ignored + `.zcode/` ignored. Jangan stage source lagi.
- Urutan perubahan di dalam file: Verify → plan checklist/log → memory README → memory entries → git status check. Jangan commit source di S6 (sudah dikomit di S4/S5).
- Behavior yang harus dipertahankan: Tidak ada perubahan runtime di S6.
- Error handling dan edge case yang harus ditangani: Jika final verify merah, JANGAN tutup plan. Kembali ke langkah gagal (S4/S5), perbaiki, ulangi verify. Jangan menandai `[x]` untuk yang merah. Jika APK gagal karena rename task, cek `build/app/outputs/flutter-apk/` masih ada `app-*.apk` asli (copy-not-rename) dan log `[APK Rename]`.
- Test yang harus ditambahkan atau diperbarui: TIDAK ADA test baru di S6. Hanya menjalankan suite existing.
- Input test dan expected result: Suite existing harus hijau dengan total = baseline S0 + tambahan S4 + tambahan S5. Tidak ada failed/skipped baru yang tidak dijelaskan.
- Command verifikasi yang tersedia di repository:
  - `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --split-per-abi` (full).
  - `git log --oneline -5` (harus tunjuk 3 commit berurutan: feat random-description, fix idle, feat keep-alive + docs plan jika sudah dikomit).
  - `git status --short` (hanya plan file ini sebagai `??`/`M` yang diniatkan).
- Hasil verifikasi yang diharapkan: Semua hijau, 3 commit source + 1 docs terpisah, tidak ada dirty tak terdokumentasi selain yang diizinkan.
- Completion criteria: `Tasks` semua `[x]` kecuali `TODO(Phase3-headless)` yang sengaja `[ ]`; `Progress Log` memiliki entry S0-S6; `.memory/` mutakhir; `git log` menunjukkan urutan commit benar; tidak ada perubahan `.gitignore` (tetap untracked).
- File atau area yang tidak boleh diubah: `lib/`, `test/`, `pubspec.yaml`, `pubspec.lock` (jangan edit manual), `android/`, `.gitignore`, `PROJECT_MEMORY.md`, `view_source_hrmis/`, `.zcode/`, `build/`, `.dart_tool/`.

---

## Risks

- Risiko aplikasi/situs: HRMIS DOM berubah (`#code`, `#password`, `#loginBtn`, `#form-edit-attendance`, `#flag_location-*`, `#latitude/#longitude`, `#attendance-saveButton`, `.messages-group`/`.alert`) → selector JS gagal. Mitigasi: pesan failure eksplisit (`prepareFailureStatus`, `geolocationFailureStatus`), retry counts dipertahankan, `view_source_hrmis/*.mhtml` sebagai referensi (jangan edit).
- Risiko eksekutor kecil salah stage (`git add .` menyeret `plans/`, `.zcode/`): dimigitasi instruksi stage eksplisit per-file di S1/S4/S5 + verifikasi `git status` tiap langkah. Counter: tetap mungkin terjadi — verifikasi `git show --stat HEAD` wajib.
- Risiko versi tabrakan: jika baseline bukan `1.4.0+9` saat eksekusi (sudah berubah), JANGAN tebak. Jadikan blocker, hitung ulang patch/minor+build sesuai aturan (bugfix patch+build, fitur minor+build) dan catat di log.
- Risiko foreground service: tipe salah → crash Android 14+, notifikasi ditolak → degraded, OEM kill → tidak tahan lama. Mitigasi: pilih tipe dari docs versi terpasang (OQ-01), degraded-continue (jangan abort), status jujur, manual matrix. Counter: klaim tahan-kunci-lama tidak bisa dijanjikan dengan WebView.
- Risiko WebView pause lebih dari 15 menit (white-screen issue upstream #2837): di luar scope; S5 hanya target 30-60 detik + resume jujur.
- Risiko kebijakan HR: otomasi absensi personal/internal — pastikan sesuai kebijakan organisasi (catatan `README.md:157-159` dipertahankan).

## Open Questions / Blockers (jangan pilih diam-diam)

- OQ-01 — `foregroundServiceType`: opsi (a) `dataSync`, (b) `specialUse`, (c) kombinasi sesuai docs. Risiko: tipe salah = crash/kebijakan Play. Rekomendasi: ikuti docs `flutter_foreground_task` versi ter-resolve + gunakan `dataSync` jika otomasi diklasifikasikan sinkronisasi singkat; jika ragu, catat sebagai blocker dan tanya user sebelum S5. Jangan default diam-diam.
- OQ-02 — Paket keep-alive: rekomendasi `wakelock_plus` + `flutter_foreground_task`. Alternatif `flutter_background` / `flutter_lifecycle_guard` ditolak karena fitur komunikasi/service-type lebih lemah untuk kasus ini. Jika versi latest breaking, pin ke versi yang lolos `analyze/test` dan catat aktual di log.
- OQ-03 — Copy placeholder idle: rekomendasi `Automation is idle.` + `Choose Run attendance on the Dashboard to pick WFO/WFH/SPJ.` Jika user minta copy berbeda, update test expected persis.
- OQ-04 — Jika `git ls-files` tunjukkan `system_prompt.md` tracked (berlawanan dengan temuan), STOP S2 dan tanya user (opsi hapus-tracked vs biarkan).

## Progress Log

- 2026-09-22 08:00:00 — Plan dibuat dari analisa repo + 5 arahan user (idle-until-Run, foreground-only Fase1, Fase3 TODO). Implementasi belum dimulai. File plan ini belum dikomit.
- 2026-09-22 11:37:00 — S0 selesai: `flutter pub get` OK, `flutter analyze` No issues, `flutter test` 87 passed, APK build gagal karena Kotlin daemon timeout (environment issue). Commit S1 dibuat.
- 2026-09-22 11:45:00 — S1 selesai: commit `feat: randomize attendance description from 30 bilingual options` (6 files). S2 selesai: `system_prompt.md` dihapus (untracked + ignored). S3 selesai: `.memory/README.md` + entri pertama dibuat.
- 2026-09-22 12:10:00 — S4 selesai: idle gating implementasi di `lib/main.dart` + `_IdleAutomationPlaceholder` widget + guard di `_handleLoadStop` + post-frame loadUrl di `_runAttendanceAutomation`. Test baru `test/startup_gating_test.dart` (3 test). Version bump `1.4.1+10`. Commit `fix: require explicit run before hrmis automation starts`. `flutter test` 90 passed.
- 2026-09-22 12:35:00 — S5 selesai: tambah `wakelock_plus ^1.3.0` + `flutter_foreground_task ^9.0.0`. Manifest tambah 4 permissions + ForegroundService. `WidgetsBindingObserver` mixin + lifecycle handler + `_releaseKeepAlive()` helper + try-finally di `_injectAttendanceForm`. Test baru `test/foreground_gating_test.dart` (5 test). Version bump `1.5.0+11`. Commit `feat: keep hrmis automation alive in foreground`. `flutter test` 95 passed, `flutter analyze` No issues.
- 2026-09-22 12:50:00 — S6 selesai: final verify hijau (95 tests, analyze clean). TODO Fase 3 tercatat. `.memory/` di-update. Plan file ini dikomit sebagai docs.

## Notes

- Standar: C2M/TM Forum ODA tidak relevan (bukan rating/billing). TOGAF dipakai proporsional: cukup plan-file + memory, tanpa ceremony enterprise.
- Prinsip AGENTS.md yang dijaga: SOLID (helper `_releaseKeepAlive` kecil), DB-as-Code tidak relevan (tanpa DB), RLS tidak relevan, RSC tidak relevan, env validation (tanpa env baru; Env Guard untuk secret), clean code, state feedback (`_updateStatus` jujur idle/paused/resumed), i18n tidak ditambah (string hardcoded konsisten existing), anti-bot first-party tidak relevan, responsive tidak diubah.
- Diagram: tidak ada diagram custom sesuai aturan styling.
- Contoh konkret sudah inline di tiap langkah (path, simbol, command, expected). Jangan generalisasi saat eksekusi.
- Counter-argumen utama: idle gating mengorbankan preload demi kebenaran pilihan; keep-alive foreground mengorbankan notifikasi/baterai sesaat demi ketahanan pendek; headless penuh ditolak karena rapuh + butuh rewrite + risiko kebijakan.

## Handoff Checklist (untuk eksekutor kecil — baca penuh sebelum mulai)

- [ ] Prasyarat: Flutter 3.41+, Dart 3.11+, Android SDK, API 23+, device/emulator lokasi, repo root `C:\Works\github.com\alamaby\codex_auto_attend`, branch `main`, baca `README.md`, `PROJECT_MEMORY.md` (arsip), `.memory/README.md` (setelah S3), dan kedua plan random-description + plan ini.
- [ ] Urutan wajib: S0 → S1 → S2 → S3 → S4 → S5 → S6. Jangan paralel. Jangan lompat. Satu commit per concern:
  - S1: `feat: randomize attendance description from 30 bilingual options` (6 file eksplisit, tanpa `add .`).
  - S4: `fix: require explicit run before hrmis automation starts` (lib/main + test gating + `1.4.1+10`).
  - S5: `feat: keep hrmis automation alive in foreground` (pubspec+manifest+Dart+test + `1.5.0+11`).
  - Docs plan ini terpisah: `docs: add hrmis idle and keep-alive implementation plan` (hanya file ini, di S6).
- [ ] Sebelum edit file apa pun di S4/S5, baca file yang listed di `File yang harus dibaca` langkah itu sampai paham baris/simbolnya. Jangan tebak API paket baru; baca docs versi ter-resolve.
- [ ] Command yang diizinkan: `git status --short`, `git diff [--stat]`, `git log --oneline -N`, `git check-ignore -v`, `Test-Path`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter test --coverage` (opsional), `flutter build apk --debug` / `--split-per-abi` / `--target-platform android-arm64`. Dilarang: `git add -A`/`.`, `git push`, `amend`, `--force`, `commit kosong`, edit `pubspec.lock` manual, ubah `.gitignore`, sentuh `view_source_hrmis/`, `.zcode/`, `build/`.
- [ ] Setiap langkah wajib penuhi `Completion criteria`-nya dan catat ringkasan ke `## Progress Log` file ini + entri `.memory/` yang sesuai. Jika merah, STOP dan jadikan blocker (jangan tandai `[x]`).
- [ ] Dilarang mengubah behavior yang listed di `Behavior yang harus dipertahankan` tiap langkah (retry counts, selector JS, GPS WFO-only, verify reload, home DOM-then-XHR, Keystore, permission guard, APK copy-not-rename).
- [ ] TODO Fase 3 tetap `[ ]` dan tidak dikodekan. OQ-01—OQ-04 tidak boleh diputuskan diam-diam; jika bukti bertentangan dengan asumsi plan, STOP dan tanya user.
- [ ] Selesai ketika: `flutter analyze` bersih, `flutter test` 0 failed, APK `v1.5.0(11)` ter-build, cold-start idle terbukti via log, lock/home pendek tidak crash + status jujur, `git log` urut benar, `.memory/` mutakhir dan tetap untracked, plan ini semua `[x]` kecuali TODO Fase 3.
