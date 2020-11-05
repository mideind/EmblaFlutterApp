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
import 'package:url_launcher/url_launcher.dart' show launch;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import './common.dart';

class WebViewRoute extends StatefulWidget {
  final String initialURL;

  WebViewRoute({Key key, this.initialURL}) : super(key: key);

  @override
  _WebViewRouteState createState() => new _WebViewRouteState();
}

class _WebViewRouteState extends State<WebViewRoute> {
  InAppWebViewController webView;

  String _assetFilenameFromURL(String url) {
    Uri uri = Uri.parse(url);
    return "docs/" + uri.pathSegments.last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        bottomOpacity: 0.0,
        elevation: 0.0,
      ),
      body: InAppWebView(
        initialUrl: this.widget.initialURL,
        //initialFile: "docs/about.html",
        initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
          debuggingEnabled: true,
          useShouldOverrideUrlLoading: true,
          transparentBackground: true,
        )),
        onWebViewCreated: (InAppWebViewController controller) {
          webView = controller;
        },
        onLoadStart: (InAppWebViewController controller, String url) {
          dlog('Loading URL $url');
        },
        onLoadError: (InAppWebViewController controller, String url, int i, String s) async {
          dlog('Page load error for $url: $i, $s');
          String path = _assetFilenameFromURL(url);
          dlog('Falling back to local asset $path');
          setState(() {
            controller.loadFile(assetFilePath: path);
          });
        },
        onLoadHttpError: (InAppWebViewController controller, String url, int i, String s) async {
          dlog('Page load error for $url: $i, $s');
          String path = _assetFilenameFromURL(url);
          dlog('Falling back to local asset $path');
          setState(() {
            controller.loadFile(assetFilePath: path);
          });
        },
        shouldOverrideUrlLoading:
            (InAppWebViewController controller, ShouldOverrideUrlLoadingRequest req) async {
          dlog("Opening external URL ${req.url}");
          if (req.url != this.widget.initialURL) {
            launch(req.url);
            return ShouldOverrideUrlLoadingAction.CANCEL;
          }
          return ShouldOverrideUrlLoadingAction.ALLOW;
        },
      ),
    );
  }
}
