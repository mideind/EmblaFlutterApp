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

// Singleton class to monitor internet connectivity

import 'package:connectivity/connectivity.dart';

import './common.dart';

class ConnectivityMonitor {
  var subscription;
  bool isConnected = true;

  static final ConnectivityMonitor _instance = ConnectivityMonitor._privateConstructor();

  // Singleton pattern
  factory ConnectivityMonitor() {
    return _instance;
  }

  // Constructor
  ConnectivityMonitor._privateConstructor();

  Future<void> start() async {
    dlog('Starting internet connectivity tracking');
    ConnectivityResult res = await Connectivity().checkConnectivity();
    isConnected = (res != ConnectivityResult.none);
    dlog("Internet connectivity: ${isConnected.toString()}");
    // Start listening
    subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      dlog('Checking internet connectivity status');
      bool conn = (result != ConnectivityResult.none);
      if (conn == true && conn != isConnected) {
        dlog('Now connected to the internet');
      } else if (conn == false && conn != isConnected) {
        dlog('No longer connected to the internet');
      }
      isConnected = conn;
    });
  }

  void stop() {
    subscription.cancel();
    subscription = null;
  }

  bool get connected {
    return (subscription != null && isConnected);
  }
}
