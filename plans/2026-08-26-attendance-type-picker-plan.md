# Attendance Type Picker Plan

Created: 2026-08-26

## Objective
Mengganti hardcode WFO dengan pilihan tipe absensi (WFO / WFH / SPJ) via bottom sheet sebelum otomasi berjalan, dan melewati validasi geolocation untuk WFH/SPJ.

## Scope
- Enum `AttendanceType` dengan mapping ke radio HRMIS (WFO=1, KEMAH=2, SPJ=3)
- Bottom sheet picker saat tap "Run attendance"
- Parameterisasi JS prepare form + skip GPS polling untuk non-WFO
- Tests unit & widget

## Milestones
1. Core module (`attendance_type.dart`, prepare JS builder)
2. Picker UI + integrasi main.dart
3. Tests
4. Dokumentasi

## Tasks
- [x] Simpan plan file
- [x] `lib/core/attendance_type.dart` + unit test (mapping ID/value, requiresGeolocation)
- [x] Bottom sheet picker + widget test (3 opsi, return pilihan, dismiss → null)
- [x] Parameterisasi JS prepare + skip GPS di `main.dart`
- [x] Update status overlay menyertakan tipe
- [x] Update README + PROJECT_MEMORY.md + plan progress

## Progress Log (lanjutan)
- 2026-08-26 — Eksekusi selesai: enum + JS builder + picker dibuat; main.dart terintegrasi; 76/76 test lulus; flutter analyze bersih.

## Risks
- Klik radio via `.click()` sudah terbukti memicu handler jQuery toggle `wfoOnly` (pola sama dengan kode WFO lama)
- Jika HRMIS mengubah id `KEMAH`, fallback selector by value menjaga kompatibilitas
- Non-WFO tetap menunggu form ready (description visible) tapi tanpa cek `#latitude`/`#location-list`

## Progress Log
- 2026-08-26 — Rencana dibuat setelah analisis view_source_hrmis dan konfirmasi user (KEMAH = WFH; dialog saat Run).

## Notes
Temuan kunci dari view_source_hrmis:
- Radio group `flag_location`: WFO value=1 (#flag_location-WFO), "Kemah (Kerja di rumah)" value=2 (#flag_location-KEMAH), SPJ value=3 (#flag_location-SPJ)
- Submit handler HRMIS: geofence check hanya jika flagLocation == 1; klik radio non-WFO memicu `$("#wfoOnly").hide()`
- `#latitude`/`#longitude` ada langsung di dalam form (bukan di wfoOnly) — selalu ada di DOM
- `start_description` required untuk semua tipe
