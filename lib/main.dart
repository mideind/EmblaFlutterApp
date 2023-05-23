/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
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

/// App initialization and presentation of main (session) view.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wakelock/wakelock.dart' show Wakelock;
import 'package:permission_handler/permission_handler.dart';
import 'package:adaptive_theme/adaptive_theme.dart' show AdaptiveTheme, AdaptiveThemeMode;

import 'package:embla_core/embla_core.dart';

import './animations.dart' show preloadAnimationFrames;
import './common.dart';
import './loc.dart' show LocationTracker;
import './prefs.dart' show Prefs;
import './session.dart' show SessionRoute;
import './theme.dart' show lightThemeData, darkThemeData;
import './hotword.dart' show HotwordDetector;
import './web.dart' show preloadHTMLDocuments;
// import './util.dart' show readServerAPIKey;

void main() async {
  // Initialize Flutter bindings before calling runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Load prefs, populate with default values if required
  await Prefs().load();
  final bool launched = Prefs().boolForKey('launched');
  if (launched == false) {
    // This is the first launch of the app
    Prefs().setDefaults();
  }

  // Make sure we change voice "Kona" or "Dóra" to new "Gudrun" voice.
  // Previous versions of the app used "Kona" as the default voice with the
  // option of "Karl" as an alternative. As of 1.3.0, we use proper voice
  // names, and as of 1.3.2 "Guðrún" is the default voice, replacing "Dóra",
  // and "Gunnar" is the alternative male voice, replacing "Karl".
  const Map<dynamic, String> oldVoicesToNew = {
    null: kDefaultVoiceID,
    "Kona": kDefaultVoiceID,
    "Dóra": kDefaultVoiceID,
    "Dora": kDefaultVoiceID,
    "Karl": "Gunnar",
  };
  if (launched == true && kDebugMode == false) {
    // We're not running for the first time
    final String? voiceID = Prefs().stringForKey("voice_id");
    if (oldVoicesToNew.containsKey(voiceID)) {
      Prefs().setStringForKey("voice_id", oldVoicesToNew[voiceID]!);
    }
  }
  // If user upgraded from pre-Ratatoskur client version, set default server
  if (Prefs().stringForKey("ratatoskur_server") == null) {
    Prefs().setStringForKey("ratatoskur_server", kDefaultRatatoskurServer);
  }
  // If user upgraded from pre-Ratatoskur client version, set default ASR engine
  if (Prefs().stringForKey("asr_engine") == null) {
    Prefs().setStringForKey("asr_engine", kDefaultASREngine);
  }
  // Make sure query_server is set
  if (Prefs().stringForKey("query_server") == null) {
    Prefs().setStringForKey("query_server", kDefaultQueryServer);
  }

  dlog("Shared prefs: ${Prefs()}");

  // Init/preload these to prevent any lag after launching app
  await preloadAnimationFrames();
  await preloadHTMLDocuments();
  await EmblaSession.prepare();

  // Initialize singleton, loading hotword-related assets into memory
  HotwordDetector();

  // Immediately fetch token from server to prevent any delay when session starts
  // var cfg = EmblaSessionConfig();
  // cfg.apiKey = readServerAPIKey();
  // await EmblaSessionConfig().fetchToken();

  // Activate wakelock to prevent device from going to sleep.
  // This wakelock is disabled when leaving the main session route.
  Wakelock.enable();

  // Request permissions.
  // We need microphone (and, ideally, location) permissions to function as expected.
  final Map<Permission, PermissionStatus> statuses = await [
    Permission.microphone,
    Permission.location,
  ].request();

  if (statuses[Permission.microphone]!.isDenied) {
    dlog("Microphone permission is denied.");
  }

  if (statuses[Permission.location]!.isDenied) {
    dlog("Location permission is denied.");
    // User has probably explicitly denied location permission so
    // we disable location sharing in Prefs to reflect that choice.
    Prefs().setBoolForKey('share_location', false);
  } else {
    LocationTracker().start();
  }

  // Launch app
  runApp(const EmblaApp());
}

class EmblaApp extends StatelessWidget {
  const EmblaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap app in AdaptiveTheme to support light/dark mode dynamic switching
    return AdaptiveTheme(
      light: lightThemeData,
      dark: darkThemeData,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: kSoftwareName,
        theme: theme,
        darkTheme: darkTheme,
        home: const SessionRoute(),
      ),
    );
  }
}
