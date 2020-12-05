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

// Singleton class w. headless web view to execute JS code

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class JSExecutor {
  JSExecutor._privateConstructor();
  static final JSExecutor _instance = JSExecutor._privateConstructor();
  factory JSExecutor() {
    return _instance;
  }

  HeadlessInAppWebView headlessWebView;

  void _constructWebView() {
    if (headlessWebView != null) {
      return;
    }
    headlessWebView = new HeadlessInAppWebView(
        initialUrl: "about:blank",
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            debuggingEnabled: true,
          ),
        ));
  }

  void runJavascript(String jsCode) {
    _constructWebView();
  }
}
