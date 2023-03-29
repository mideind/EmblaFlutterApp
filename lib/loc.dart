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

/// Singleton wrapper for location tracking.

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import './common.dart';
import './prefs.dart';

/// Location tracking singleton.
class LocationTracker {
  LocationTracker._constructor();
  static final LocationTracker _instance = LocationTracker._constructor();

  factory LocationTracker() {
    return _instance;
  }

  double? _lat;
  double? _lon;
  StreamSubscription<Position>? _positionStream;

  /// Start location tracking.
  void start() async {
    // We never start location tracking if it's disabled in prefs or if we don't have permission
    if (Prefs().boolForKey('share_location') == false ||
        await Permission.location.isGranted == false) {
      dlog("Could not start location tracking, permission not granted");
      return;
    }
    if (_positionStream != null) {
      // Location tracking already ongoing
      return;
    }

    dlog('Starting location tracking');
    _positionStream = Geolocator.getPositionStream().listen((Position? position) {
      if (position == null) {
        known = false;
        return;
      }
      _lat = position.latitude;
      _lon = position.longitude;
      //dlog("Location: ${lat.toString()}, ${lon.toString()}");
    });
  }

  /// Stop location tracking.
  void stop() {
    if (_positionStream != null) {
      dlog('Stopping location tracking');
      _positionStream?.cancel();
      _positionStream = null;
      known = false;
    }
  }

  /// Is the current location known?
  bool get known {
    return (_lat != null && _lon != null);
  }

  // private
  set known(bool val) {
    if (val == false) {
      _lat = null;
      _lon = null;
    }
  }

  /// Returns a list of two doubles ([lat, lon]) representing
  /// WGS84 coordinates or null if location is unknown
  List<double>? get location {
    if (!known) {
      return null;
    }
    return [_lat!, _lon!];
  }
}
