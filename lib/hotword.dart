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

// Singleton wrapper class for hotword detection ("Hæ Embla")

import 'dart:async';
import 'dart:io';

// import 'package:flutter/services.dart' show rootBundle;
// import 'package:path_provider/path_provider.dart';

import './common.dart' show dlog;

class HotwordDetector {
  static final HotwordDetector _instance = HotwordDetector._internal();

  // Singleton pattern
  factory HotwordDetector() {
    return _instance;
  }

  // Constructor
  HotwordDetector._internal();

  // Start hotword detection
  Future<void> start(Function hotwordHandler, Function(dynamic) errHandler) async {
    dlog('Starting hotword detection');
  }

  // Stop hotword detection
  Future<void> stop() async {
    dlog('Stopping hotword detection');
  }

  // Release any assets loaded by hotword detector
  void purge() {}
}
