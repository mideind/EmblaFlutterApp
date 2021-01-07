/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
 * Author: Sveinbjorn Thordarson
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:geolocator/geolocator.dart';
import 'package:wakelock/wakelock.dart' show Wakelock;

import './prefs.dart' show Prefs;
import './session.dart' show SessionRoute;
import './loc.dart' show LocationTracking;
import './animations.dart' show preloadAnimationFrames;
import './audio.dart' show AudioPlayer;
import './theme.dart' show defaultTheme;
import './common.dart' show dlog, kSoftwareName;

void main() async {
  // Initialize bindings before calling runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Only enable HTTP communication logging in debug mode
  if (kReleaseMode == false) {
    HttpClient.enableTimelineLogging = true;
  }

  // Load prefs, populate with default values if required
  await Prefs().load();
  bool launched = Prefs().boolForKey('launched');
  if (launched == null || launched == false) {
    Prefs().setDefaults();
  }
  dlog("Shared prefs: ${Prefs().desc()}");

  // Init/preload these to prevent any lag after launching app
  await preloadAnimationFrames();
  AudioPlayer(); // Initialize singleton

  // Activate wake lock to prevent device from going to sleep
  // This wakelock is disabled when leaving session route
  Wakelock.enable();

  // Set up location tracking
  if (Prefs().boolForKey('share_location') == true) {
    // Wrap in try/catch in case another location permission request is ongoing
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        LocationTracking().start();
      }
    } catch (err) {
      LocationTracking().start();
    }
  }

  // Launch app
  runApp(MaterialApp(title: kSoftwareName, home: SessionRoute(), theme: defaultTheme));
}
