# Second Run Already-Recorded Detection Fix

Created: 2026-09-23 10:00:00

## Objective

Run ke-n (setelah sudah absen) harus selesai dalam <=10 detik: deteksi `recorded` lalu langsung ke
home inspection, tanpa mengisi form, tanpa menunggu GPS, tanpa klik save. Bila ragu setelah
10 detik -> status `failed` dan minta retry manual, tidak pernah nekat submit (risiko clock-out).

## Scope

- `lib/core/attendance_recorded_js.dart` (baru) — JS builder + classifier murni
- `lib/core/status_messages.dart` — pesan baru
- `lib/main.dart` — polling, short-circuit, guard save, debounce load-stop
- `lib/core/attendance_prepare_js.dart` — guard disabled
- `test/attendance_recorded_test.dart` (baru), `test/status_messages_test.dart`
- `pubspec.yaml` — 1.5.1+12 (bugfix -> patch +1, build +1)

## Milestones

1. Deteksi recorded berbasis sinyal ganda (S1/S2/S3/S4)
2. Short-circuit + status gagal yang aman
3. Guard submit (cegah clock-out)
4. Verifikasi analyze/test + build

## Tasks

- [x] T1 `lib/core/attendance_recorded_js.dart` — enum `AttendanceFormState` + JS builder
- [x] T2 `lib/main.dart` — ganti cek sekali dengan polling T1 (1s x 10)
- [x] T3 Short-circuit `recorded` -> `_navigateToHomeForInspection()`
- [x] T4 Timeout `pending` + S1 pernah terlihat -> `failed` + balik ke tab Dashboard
- [x] T5 Guard prepare JS saat field di-`disabled`
- [x] T6 Guard `_submitAttendanceFormJs` -- save button hidden/disabled -> jangan klik
- [x] T7 Verify reload pakai polling yang sama (asimetri sengaja: S1 cukup di jalur verify)
- [x] T8 Debounce `_handleLoadStop` (<1.5s, URL sama)
- [x] T9 `flutter pub get` / `flutter analyze` / `flutter test` / `flutter build apk --split-per-abi`

## Progress Log

- 2026-09-23 09:46:16 — Implementasi selesai: `flutter analyze` bersih, `flutter test` 111 lolos,
  `flutter build apk --split-per-abi` menghasilkan `HRMIS-Helper-v1.5.1(12)-*-release.apk`.
  Versi 1.5.1+12. Perbaikan penting saat implementasi: `AttendanceFormSignals.parse` memecah
  `<state>|<flags>` dulu karena hasil JS selalu membawa payload flag (tanpa ini hasil recorded
  tidak pernah cocok). Tinggal verifikasi manual di device (run kedua WFO/WFH/SPJ, skenario
  jaringan mati, tanpa POST save pada run ke-n).

## Risks

- S4 override S1: bila HRMIS salah render tombol "Clock in" saat sudah absen, automasi akan mencoba
  absen. HRMIS selalu `hide()` tombol di cabang `!canAttend`, dan T6 tetap memblokir tombol
  hidden, jadi risiko praktis rendah.
- S1 bergantung teks Inggris HRMIS (`You are signed in today on`). Bila wording berubah, S1 mati ->
  fallback `open` = perilaku lama, jadi regresi terburuk hanya balik ke bug ini.
- Asimetri T7 sengaja: di jalur verify, S1/S2/S3 sudah cukup karena POST sudah terjadi; di jalur
  utama S1 saja tidak cukup. Didokumentasikan di kode agar tidak "dirapikan" keliru nanti.
- Polling menambah latensi run pertama yang belum absen; dikurangi dengan early-exit saat S4
  (`open`) terverifikasi, biasanya <3 detik.

## Progress Log

- 2026-09-23 10:00:00 — Rencana dibuat dari screenshot run kedua (overlay `Waiting for GPS (8/20)...`
  lalu `GPS position not detected. Enable device location and retry.`) + analisis
  `temp/view-source_https___hrmis.neuron.id_attendance_dashboard_form.htm`.
- 2026-09-23 10:20:00 — User memutuskan: timeout + hanya S1 terlihat -> `failed` / retry manual
  (bukan asumsikan recorded, bukan paksa save). Timeout 10 detik.

## Notes

### Diagnosis (bukan race AJAX — selector yang meleset)

1. **Sinyal `recorded` sudah ada di HTML server sejak awal load**, pada `#form-edit-attendance`
   region (decoded line ~20772):

   ```html
   <p class="section-title text-italic text-danger ml-auto msgAttendance">You are signed in today on 07:34</p>
   ```

   Sedangkan pengecekan recorded di `lib/main.dart` hanya memindai `.messages-group`,
   `.messages-group strong`, `.alert.alert-success`, `.alert-success`, `.alert[role="alert"]`,
   `[role="alert"]`, `.alert`, `.message`, `.success` — `.msgAttendance` tidak masuk daftar. Hasilnya
   `attendance-not-recorded` palsu, form tetap diisi.

2. **Kenapa GPS 20/20 gagal.** `getLocation()` — satu-satunya yang mengisi `#latitude`/`#longitude`
   — hanya dipanggil bila `canAttend`:

   ```js
   checkAttendance().then((canAttend) => { if (canAttend) { getLocation(); } })
   ```

   State `recorded` -> `canAttend=false` -> `getLocation()` tak pernah jalan -> hidden input
   `#latitude` kosong -> `_checkGeolocationReadyJs` selamanya `geolocation-missing`. Persis overlay
   pada screenshot kedua.

3. **Screenshot membuktikan halaman memang sudah `recorded`:** popup map
   `"You attended from here"` berasal dari `attendPoint()` yang hanya dipanggil di cabang
   `!canAttend && attendId`; tombol bawah hanya `Close` karena `$("#attendance-saveButton").hide()`;
   radio WFO ter-check karena `$("#card-location").find(input[value=1]).attr('checked', true)`;
   description masih terisi karena `attdStartDesc.text(attendDsc)`. Banner hijau
   `Attendance has been recorded.` memang ada di DOM, tapi di-`prepend` ke `#tabAttendance`
   sehingga posisinya di atas field Description — keluar viewport, tertutup status overlay.

4. **Bahaya kalau dibiarkan:** `#attendance-saveButton` adalah `<a class="btn btn-primary">`, tetap
   bisa di-`.click()` walau di-`hide()`. Kalau gate GPS terlewat, POST ke
   `/attendance/attendance/save` dapat menghasilkan clock-out, bukan clock-in.

### Signal table

| Code | Sinyal | Kapan muncul | Berat |
| ---- | ------ | ------------ | ------ |
| S1 | `p.msgAttendance` cocok `/you are signed in today on/i` | langsung, server-rendered | cukup untuk memicu `pending`, tidak cukup untuk `recorded` |
| S2 | `.messages-group strong` "attendance has been recorded" / `.msgAttendance.text-success` / span `.messages` "has been recorded at" | setelah AJAX `checkAttendance` | kuat -> `recorded` |
| S3 | `textarea[name="start_description"][disabled]` + `#attendance-saveButton` tak terlihat + `.radio-flag-location[disabled]` | setelah AJAX `checkAttendance` | kuat -> `recorded` |
| S4 | `#attendance-saveButton` terlihat + `#attendance-saveButton-text` cocok `/clock in\|clock out/i` | setelah AJAX, `canAttend=true` | kuat -> `open` (menang atas S1) |

### Related

- Screenshots user: run kedua 07:36 & 07:57, overlay `Waiting for GPS (8/20)...` ->
  `GPS position not detected. Enable device location and retry.`
- Source dump: `temp/view-source_https___hrmis.neuron.id_attendance_dashboard_form.htm`
- Rencana terkait: `plans/2026-08-27-attendance-picker-and-status-fix.md`
- Reference domain: n/a (project kecil, TOGAF tidak perlu penuh; perubahan scoped pada bugfix).
