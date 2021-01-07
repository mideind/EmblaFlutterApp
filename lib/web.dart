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

// Documentation web views

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart' show launch;

import './common.dart';

const String kLoadingHTMLFile = 'docs/loading.html';

class WebViewRoute extends StatefulWidget {
  final String initialURL;

  WebViewRoute({Key key, this.initialURL}) : super(key: key);

  @override
  _WebViewRouteState createState() => new _WebViewRouteState();
}

class _WebViewRouteState extends State<WebViewRoute> {
  InAppWebViewController webView;

  // Fall back to local HTML document if error comes up when fetching from remote server
  void errHandler(InAppWebViewController controller, String url, int errCode, String desc) async {
    dlog("Page load error for $url: $errCode, $desc");
    String path = _fallbackAssetForURL(url);
    dlog("Falling back to local asset $path");
    setState(() {
      controller.loadFile(assetFilePath: path);
    });
  }

  // Path to local asset with same filename as remote document
  String _fallbackAssetForURL(String url) {
    Uri uri = Uri.parse(url);
    return "docs/${uri.pathSegments.last}";
  }

  // Handle clicks on links in HTML documentation.
  // These links should be opened in an external browser.
  Future<ShouldOverrideUrlLoadingAction> urlClickHandler(
      InAppWebViewController controller, ShouldOverrideUrlLoadingRequest req) async {
    String fallbackFilename = _fallbackAssetForURL(req.url);
    if (req.url != this.widget.initialURL && req.url.endsWith(fallbackFilename) == false) {
      dlog("Opening external URL: ${req.url}");
      launch(req.url);
      return ShouldOverrideUrlLoadingAction.CANCEL;
    }
    return ShouldOverrideUrlLoadingAction.ALLOW;
  }

  // void loadCompletionHandler(InAppWebViewController controller, String url) {
  //   if (url.endsWith('loading.html')) {
  //     setState(() {
  //       controller.loadUrl(url: null);
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // Create web view
    var view = InAppWebView(
      // initialUrl: this.widget.initialURL,
      initialFile: kLoadingHTMLFile,
      initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
        debuggingEnabled: kReleaseMode,
        useShouldOverrideUrlLoading: true,
        transparentBackground: true,
      )),
      //onWebViewCreated: (InAppWebViewController controller) {},
      onLoadStart: (InAppWebViewController controller, String url) {
        dlog("Loading URL $url");
      },
      onLoadStop: (InAppWebViewController controller, String url) {
        if (url.endsWith(kLoadingHTMLFile)) {
          setState(() {
            controller.loadUrl(url: this.widget.initialURL);
          });
        }
      },
      onLoadError: errHandler,
      onLoadHttpError: errHandler,
      shouldOverrideUrlLoading: urlClickHandler,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        bottomOpacity: 0.0,
        elevation: 0.0,
      ),
      body: view,
    );
  }
}
