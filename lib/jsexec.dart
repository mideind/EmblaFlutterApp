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

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'common.dart';
// TODO: Better error handling

class JSExecutor {
  static final JSExecutor _instance = JSExecutor._internal();
  HeadlessInAppWebView headlessWebView;

  // Singleton pattern
  factory JSExecutor() {
    return _instance;
  }

  // Constructor
  JSExecutor._internal() {
    // Only called once, when singleton is instantiated
    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse("about:blank")),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(),
      ),
      onWebViewCreated: (controller) {
        dlog('HeadlessInAppWebView created!');
      },
      onConsoleMessage: (controller, consoleMessage) {
        dlog("JAVASCRIPT CONSOLE MESSAGE: ${consoleMessage.message}");
      },
    );
  }

  Future<String> run(String jsCode) async {
    await headlessWebView.dispose();
    await headlessWebView.run();
    String answer = "Upp kom villa.";
    try {
      var result =
          await headlessWebView.webViewController.callAsyncJavaScript(functionBody: jsCode);
      if (result.error == null && result.value != null) {
        answer = result.value.toString();
      }
    } on Exception {
      dlog("ERROR: HeadlessInAppWebView is not running!");
    }
    return answer;
  }
}
