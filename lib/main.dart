/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2022 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// App initialization and presentation of main (session) view

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart' show Wakelock;
import 'package:permission_handler/permission_handler.dart';

import 'package:adaptive_theme/adaptive_theme.dart';

import './animations.dart' show preloadAnimationFrames;
import './audio.dart' show AudioPlayer;
import './common.dart' show dlog, kSoftwareName;
import './loc.dart' show LocationTracking;
import './prefs.dart' show Prefs;
import './session.dart' show SessionRoute;
import './theme.dart' show lightThemeData, darkThemeData;
import './hotword.dart' show HotwordDetector;

void main() async {
  // Initialize bindings before calling runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Load prefs, populate with default values if required
  await Prefs().load();
  bool launched = Prefs().boolForKey('launched');
  if (launched == null || launched == false) {
    Prefs().setDefaults();
  }
  // Make sure we map voice "Kona" to "Dora" for backward compatibility
  // Previous versions of the app used "Kona" as the default voice with
  // the option of "Karl" as an alternative. As of 1.3.0, we now use
  // voice names e.g. "Dora"
  if (Prefs().stringForKey("voice_id") == "Kona") {
    Prefs().setStringForKey("voice_id", "Dóra");
  }
  dlog("Shared prefs: ${Prefs().desc()}");

  // Init/preload these to prevent any lag after launching app
  await preloadAnimationFrames();
  AudioPlayer();
  HotwordDetector();

  // Activate wake lock to prevent device from going to sleep
  // This wakelock is disabled when leaving session route
  Wakelock.enable();

  // Request microphone permission
  PermissionStatus status = await Permission.microphone.request();
  if (status != PermissionStatus.granted) {
    dlog("Microphone permission refused");
  }

  // Request and activate location tracking
  if (Prefs().boolForKey('share_location') == true) {
    // Wrap in try/catch in case another location permission request is ongoing.
    // This is a hack. For some reason, some versions of Android can activate a
    // location permission request without being triggered by the Flutter
    // permissions package, and simultaneous requests trigger an exception.
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        LocationTracking().start();
      } else {
        Prefs().setBoolForKey('share_location', false);
      }
    } catch (err) {
      LocationTracking().start();
    }
  }

  // Launch app with session route
  runApp(EmblaApp());
}

class EmblaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightThemeData,
      dark: darkThemeData,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: kSoftwareName,
        theme: theme,
        darkTheme: darkTheme,
        home: SessionRoute(),
      ),
    );
  }
}
