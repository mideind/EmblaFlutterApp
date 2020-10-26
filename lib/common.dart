import 'package:flutter/foundation.dart';

void dlog(String logStr) {
  if (kReleaseMode) {
    return;
  }
  print(logStr);
}

const String DEFAULT_SERVER = "https://greynir.is";
