import 'dart:math';

/// One bilingual attendance description (English + Indonesian versions of the
/// same message). Entries must not contain apostrophes, backslashes, or
/// newlines because the picked text is spliced into a single-quoted JS string.
class AttendanceDescription {
  final String english;
  final String indonesian;

  const AttendanceDescription(this.english, this.indonesian);
}

/// Work-motivation descriptions in a mixed tone: mostly neutral, a few with a
/// spiritual touch, following the app's original description style.
const List<AttendanceDescription> kAttendanceDescriptions = [
  AttendanceDescription('Ready to work hard today!', 'Siap bekerja keras hari ini!'),
  AttendanceDescription('A new day, a new spirit.', 'Hari baru, semangat baru.'),
  AttendanceDescription('Looking forward to a productive day.', 'Semoga hari ini produktif.'),
  AttendanceDescription('Bismillah, let us start the day with full energy!', 'Bismillah, mari mulai hari dengan energi penuh!'),
  AttendanceDescription('Focused and ready to deliver.', 'Fokus dan siap memberikan yang terbaik.'),
  AttendanceDescription('Another great day to grow and learn.', 'Hari yang baik untuk tumbuh dan belajar.'),
  AttendanceDescription('Alhamdulillah, still given the chance to work today.', 'Alhamdulillah, masih diberi kesempatan bekerja hari ini.'),
  AttendanceDescription('Small steps every day, big results over time.', 'Langkah kecil setiap hari, hasil besar di masa depan.'),
  AttendanceDescription('Teamwork makes the work lighter.', 'Kerja sama membuat pekerjaan lebih ringan.'),
  AttendanceDescription('Staying positive and productive today.', 'Tetap positif dan produktif hari ini.'),
  AttendanceDescription('Time to shine and do the best work.', 'Saatnya bersinar dan memberikan yang terbaik.'),
  AttendanceDescription('Bismillah, may today run smoothly.', 'Bismillah, semoga hari ini lancar.'),
  AttendanceDescription('Every task is a chance to improve.', 'Setiap tugas adalah kesempatan untuk berkembang.'),
  AttendanceDescription('Bringing good energy to the workplace.', 'Membawa energi positif ke tempat kerja.'),
  AttendanceDescription('Consistency is the key to success.', 'Konsistensi adalah kunci kesuksesan.'),
  AttendanceDescription('Ready to face any challenge today.', 'Siap menghadapi tantangan apa pun hari ini.'),
  AttendanceDescription('Work with heart, finish with pride.', 'Bekerja dengan hati, selesaikan dengan bangga.'),
  AttendanceDescription('May today be smooth and blessed.', 'Semoga hari ini lancar dan penuh berkah.'),
  AttendanceDescription('Discipline today, achievement tomorrow.', 'Disiplin hari ini, prestasi esok hari.'),
  AttendanceDescription('Happy to start another working day.', 'Senang memulai hari kerja lagi.'),
  AttendanceDescription('Bismillah, keep the spirit up!', 'Bismillah, semangat bekerja!'),
  AttendanceDescription('Do the best, expect the best.', 'Lakukan yang terbaik, harapkan yang terbaik.'),
  AttendanceDescription('A productive day starts with a good intention.', 'Hari produktif dimulai dengan niat yang baik.'),
  AttendanceDescription('Stay focused, stay humble.', 'Tetap fokus, tetap rendah hati.'),
  AttendanceDescription('Alhamdulillah for the energy to work today.', 'Alhamdulillah atas energi untuk bekerja hari ini.'),
  AttendanceDescription('Turning plans into action today.', 'Mengubah rencana menjadi tindakan hari ini.'),
  AttendanceDescription('Good attitude, good results.', 'Sikap yang baik, hasil yang baik.'),
  AttendanceDescription('One task at a time, all will be done.', 'Satu tugas demi satu tugas, semua akan selesai.'),
  AttendanceDescription('Bismillah, today is another chance to be better.', 'Bismillah, hari ini kesempatan lagi untuk lebih baik.'),
  AttendanceDescription('Finish strong, start stronger.', 'Selesaikan dengan kuat, mulai lebih kuat.'),
];

/// Picks one of the [kAttendanceDescriptions] at random, then one of its two
/// language versions at random. Call once per attendance session (not per
/// prepare retry) so the description stays stable across retries.
String pickRandomAttendanceDescription([Random? random]) {
  final rng = random ?? Random();
  final entry = kAttendanceDescriptions[rng.nextInt(kAttendanceDescriptions.length)];
  return rng.nextBool() ? entry.english : entry.indonesian;
}
