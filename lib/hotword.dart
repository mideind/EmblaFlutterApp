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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:porcupine/porcupine_manager.dart';
import 'package:porcupine/porcupine_error.dart';

import './common.dart' show dlog;

class HotwordDetector {
  // Class variables
  PorcupineManager pm;
  String ppnPath;

  // Constructor
  static final HotwordDetector _instance = HotwordDetector._internal();

  // Singleton pattern
  factory HotwordDetector() {
    return _instance;
  }

  // Initialization
  HotwordDetector._internal() {}

  Future<void> start(Function hotwordHandler, Function errHandler) async {
    dlog('Starting hotword detection');
    try {
      if (ppnPath == null) {
        ppnPath = await copyPPNToTemp();
      }
      pm = await PorcupineManager.fromKeywordPaths([ppnPath], (idx) {
        hotwordHandler();
      });
    } on PvError catch (err) {
      dlog(err.toString());
      errHandler();
    }
    await pm.start();
  }

  Future<void> stop() async {
    dlog('Stopping hotword detection');
    await pm.stop();
  }

  void purge() {
    pm.delete();
  }

  Future<String> copyPPNToTemp() async {
    final filename = 'hey_emm_blah_ios.ppn';
    var bytes = await rootBundle.load("assets/ppn/hey_emm_blah_ios.ppn");
    String dir = (await getApplicationDocumentsDirectory()).path;
    String finalPath = "$dir/$filename";
    writeToFile(bytes, finalPath);
    return finalPath;
  }

//write to app path
  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
}
