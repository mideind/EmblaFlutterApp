/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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

import './common.dart';
import './prefs.dart';

class LocationTracking {
  LocationTracking._privateConstructor();
  static final LocationTracking _instance = LocationTracking._privateConstructor();
  factory LocationTracking() {
    return _instance;
  }

  double lat;
  double lon;
  bool known = false;
  StreamSubscription<Position> positionStream;

  void start() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Prefs().setBoolForKey('share_location', false);
        return;
      }
    } catch (err) {
      dlog("Error requesting permission: $err");
    }

    if (positionStream != null) {
      // Already ongoing
      return;
    }
    dlog('Starting location tracking');
    positionStream = Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.best)
        .listen((Position position) {
      if (position == null) {
        known = false;
        return;
      }
      lat = position.latitude;
      lon = position.longitude;
      known = true;
      //dlog("Location: ${lat.toString()}, ${lon.toString()}");
    });
  }

  void stop() {
    if (positionStream != null) {
      dlog('Stopping location tracking');
      positionStream?.cancel();
      positionStream = null;
      known = false;
    }
  }

  List<double> get location {
    if (!known || lat == null || lon == null) {
      return null;
    }
    return [lat, lon];
  }
}
