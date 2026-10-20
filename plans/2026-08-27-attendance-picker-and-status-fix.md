# Attendance Picker & Status Fix

Created: 2026-08-27

## Objective
(1) Picker wajib muncul tiap Run termasuk after-save kredensial (Opsi B + bottomsheet). (2) Hilangkan GPS position not detected yang menetap setelah sukses dan perbaiki validasi location-list.

## Scope
lib/main.dart, lib/attendance_type_picker.dart, lib/core/attendance_prepare_js.dart, lib/core/status_messages.dart, test/*

## Milestones
1. Observability
2. Picker (P1)
3. Status & Geolocation (P1)
4. Verifikasi

## Tasks
- [x] T1 Observability — log picker + recordedResult
- [x] T2 Picker bottomsheet robust (useRootNavigator, Builder context) + bypass Opsi B (_openCredentialScreen -> _onRunAttendancePressed)
- [x] T3 Race & status persistence guard
- [x] T4 location-list dilonggarkan (warning bukan fail bila lat/lng ready)
- [x] T5 Selector already-recorded diperluas ke .alert.alert-success
- [x] T6 Tests + T7 dart format / flutter analyze / flutter test / manual v1.3.x

## Progress Log
- 2026-08-27 — Rencana dibuat dari screenshot 07:31-07:36; user pilih Opsi B + bottomsheet untuk ekstensibilitas.
- 2026-08-27 — Eksekusi selesai. Fix picker (Builder+rootNavigator), bypass credential (Opsi B), race guard, location-list optional, selector diperluas. Verifikasi: analyze clean, 81 tests pass. Bump 1.3.1+8.
