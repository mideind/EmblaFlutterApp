/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
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

// Documentation web views

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show launch;

import './common.dart';

Widget _webviewForURL(String url) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      bottomOpacity: 0.0,
      elevation: 0.0,
    ),
    body: WebView(
      initialUrl: url,
      navigationDelegate: (NavigationRequest request) {
        // All external URLs should be opened in a browser
        if (request.url != url) {
          launch(request.url);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ),
  );
}

class AboutRoute extends StatelessWidget {
  final initialURL = ABOUT_URL;
  @override
  Widget build(BuildContext context) {
    return _webviewForURL(initialURL);
  }
}

class InstructionsRoute extends StatelessWidget {
  final initialURL = INSTRUCTIONS_URL;
  @override
  Widget build(BuildContext context) {
    return _webviewForURL(initialURL);
  }
}

class PrivacyRoute extends StatelessWidget {
  final initialURL = PRIVACY_URL;
  @override
  Widget build(BuildContext context) {
    return _webviewForURL(initialURL);
  }
}
