import 'package:flutter/foundation.dart';

void log(String message) {
  if (!kReleaseMode) {
    debugPrint(message);
  }
}
