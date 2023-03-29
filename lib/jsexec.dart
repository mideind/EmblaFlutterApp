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

/// Singleton wrapper class around a headless web view
/// used to execute JS code payload from server.

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import './common.dart';

const kJSExecErrorMessage = "Villa kom upp við keyrslu á JavaScript kóða.";
const kJSExecDefaultWebViewURL = "about:blank";

/// Wrapper class to execute JavaScript code in a headless web view.
class JSExecutor {
  static final JSExecutor _instance = JSExecutor._constructor();
  static late HeadlessInAppWebView headlessWebView;

  // Singleton pattern
  factory JSExecutor() {
    return _instance;
  }

  // Constructor, only called once, when singleton is instantiated
  JSExecutor._constructor() {
    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse(kJSExecDefaultWebViewURL)),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(),
      ),
      onWebViewCreated: (controller) {},
      onConsoleMessage: (controller, consoleMessage) {
        dlog("JavaScript Console Message: ${consoleMessage.message}");
      },
    );
  }

  /// Run JavaScript code in a headless web view. Return eval result as string.
  Future<String> run(String jsCode) async {
    await headlessWebView.dispose();
    await headlessWebView.run();
    try {
      final CallAsyncJavaScriptResult? result =
          await headlessWebView.webViewController.callAsyncJavaScript(functionBody: jsCode);
      if (result != null && result.error == null && result.value != null) {
        return result.value.toString();
      }
    } on Exception catch (e) {
      dlog("Error running JavaScript in HeadlessInAppWebView: $e");
    }
    return kJSExecErrorMessage;
  }
}
