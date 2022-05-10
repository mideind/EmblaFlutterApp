/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2022 Miðeind ehf. <mideind@mideind.is>
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

// Singleton wrapper class around headless web view to execute JS code

import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class JSExecutor {
  static final JSExecutor _instance = JSExecutor._internal();
  final _flutterWebviewPlugin = FlutterWebviewPlugin();

  // Singleton pattern
  factory JSExecutor() {
    return _instance;
  }

  // Constructor
  JSExecutor._internal() {
    // Only called once, when singleton is instantiated
    _flutterWebviewPlugin.launch('about:blank', hidden: true);
  }

  Future<String> run(String jsCode) {
    return _flutterWebviewPlugin.evalJavascript(jsCode);
  }
}
