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

import 'package:porcupine/porcupine_manager.dart';
import 'package:porcupine/porcupine_error.dart';

import './common.dart' show dlog;

class HotwordDetector {
  // Class variables
  PorcupineManager pm;

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
      pm = await PorcupineManager.fromKeywords(["picovoice", "porcupine"], (idx) {
        hotwordHandler();
      });
    } on PvError catch (err) {
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
}
