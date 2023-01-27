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

// Singleton wrapper for location tracking

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import './common.dart';
import './prefs.dart';

/// Location tracking singleton
class LocationTracking {
  LocationTracking._privateConstructor();
  static final LocationTracking _instance = LocationTracking._privateConstructor();

  factory LocationTracking() {
    return _instance;
  }

  double? lat;
  double? lon;
  StreamSubscription<Position>? positionStream;

  /// Start location tracking
  void start() async {
    // We never start location tracking if it's disabled in prefs or if we don't have permission
    if (Prefs().boolForKey('share_location') == false ||
        await Permission.location.isGranted == false) {
      dlog("Could not start location tracking, permission not granted");
      return;
    }
    if (positionStream != null) {
      // Location tracking already ongoing
      return;
    }

    dlog('Starting location tracking');
    positionStream = Geolocator.getPositionStream().listen((Position? position) {
      if (position == null) {
        known = false;
        return;
      }
      lat = position.latitude;
      lon = position.longitude;
      //dlog("Location: ${lat.toString()}, ${lon.toString()}");
    });
  }

  /// Stop location tracking
  void stop() {
    if (positionStream != null) {
      dlog('Stopping location tracking');
      positionStream?.cancel();
      positionStream = null;
      known = false;
    }
  }

  /// Is the current location known?
  bool get known {
    return (lat != null && lon != null);
  }

  set known(bool val) {
    if (val == false) {
      lat = null;
      lon = null;
    }
  }

  /// Returns a list of doubles [lat, lon] or null if location is unknown
  List<double>? get location {
    if (!known) {
      return null;
    }
    return [lat!, lon!];
  }
}
