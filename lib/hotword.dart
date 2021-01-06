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

// Singleton wrapper class for hotword detection ("Hæ Embla")

import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:porcupine/porcupine_manager.dart';

import './common.dart' show dlog;

class HotwordDetector {
  // Class variables
  PorcupineManager pm;
  String ppnPath;

  static final HotwordDetector _instance = HotwordDetector._internal();

  // Singleton pattern
  factory HotwordDetector() {
    return _instance;
  }

  // Constructor
  HotwordDetector._internal();

  // Start hotword detection
  Future<void> start(Function hotwordHandler, Function errHandler) async {
    dlog('Starting hotword detection');
    try {
      if (ppnPath == null) {
        ppnPath = await copyPPNToTemp();
      }
      pm = await PorcupineManager.fromKeywordPaths([ppnPath], (idx) {
        dlog('Hotword detected');
        hotwordHandler();
      });
    } catch (err) {
      dlog("Error initing Porcupine: ${err.toString()}");
      errHandler();
      return;
    }
    await pm.start();
  }

  // Stop hotword detection
  Future<void> stop() async {
    if (pm == null) {
      return;
    }
    dlog('Stopping hotword detection');
    await pm?.stop();
  }

  // Release any assets loaded by hotword detector
  void purge() {
    pm?.stop();
    pm?.delete();
  }

  // Copy PPN files from asset bundle to temp directory
  Future<String> copyPPNToTemp() async {
    final filename = "${Platform.operatingSystem}.ppn";
    var bytes = await rootBundle.load("assets/ppn/$filename");
    String dir = (await getTemporaryDirectory()).path;
    String finalPath = "$dir/$filename";
    final buffer = bytes.buffer;
    File(finalPath).writeAsBytes(buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    return finalPath;
  }
}
