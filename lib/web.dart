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

// Documentation web views

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import './theme.dart' show standardAppBar;
import './common.dart' show dlog;

const String kDocsDir = 'docs';
const String kLoadingHTMLFilePath = "$kDocsDir/loading.html";
const String kLoadingDarkHTMLFilePath = "$kDocsDir/loading_dark.html";

class WebViewRoute extends StatefulWidget {
  final String initialURL;

  WebViewRoute({Key key, this.initialURL}) : super(key: key);

  @override
  WebViewRouteState createState() => WebViewRouteState();
}

class WebViewRouteState extends State<WebViewRoute> {
  InAppWebViewController webView;

  // Fall back to local HTML document if error comes up when fetching document from remote server
  void errHandler(InAppWebViewController controller, Uri url, int errCode, String desc) async {
    dlog("Page load error for $url: $errCode, $desc");
    String path = _fallbackAssetForURL(url.toString());
    dlog("Falling back to local asset $path");
    setState(() {
      controller.loadFile(assetFilePath: path);
    });
  }

  // Path to local asset with same filename as remote document
  String _fallbackAssetForURL(String url) {
    Uri uri = Uri.parse(url);
    return "$kDocsDir/${uri.pathSegments.last}";
  }

  // Handle clicks on links in HTML documentation.
  // These links should be opened in an external browser.
  Future<NavigationActionPolicy> urlClickHandler(
      InAppWebViewController controller, NavigationAction action) async {
    URLRequest req = action.request;
    String urlStr = req.url.toString();
    String fallbackFilename = _fallbackAssetForURL(urlStr);
    if (urlStr != widget.initialURL && urlStr.endsWith(fallbackFilename) == false) {
      dlog("Opening external URL: ${req.url}");
      await launchUrl(req.url, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    // Create web view that initially presents a "loading" document with
    // progress indicator. Then immediately fetch the actual remote
    // document. Falls back to loading local bundled HTML document on network error.
    var darkMode = (MediaQuery.of(context).platformBrightness == Brightness.dark);
    var loadingURL = kLoadingHTMLFilePath;
    if (darkMode) {
      loadingURL = kLoadingDarkHTMLFilePath;
    }

    InAppWebView webView = InAppWebView(
      initialFile: loadingURL,
      initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        transparentBackground: true,
      )),
      onLoadStart: (InAppWebViewController controller, Uri url) {
        dlog("Loading URL ${url.toString()}");
      },
      onLoadStop: (InAppWebViewController controller, Uri url) {
        if (url.toString().endsWith(kLoadingHTMLFilePath) ||
            url.toString().endsWith(kLoadingDarkHTMLFilePath)) {
          setState(() {
            String url = widget.initialURL;
            if (darkMode) {
              url += '?dark=1';
            }
            Uri uri = Uri.parse(url);
            controller.loadUrl(urlRequest: URLRequest(url: uri));
          });
        }
      },
      onLoadError: errHandler,
      onLoadHttpError: errHandler,
      shouldOverrideUrlLoading: urlClickHandler,
    );

    return Scaffold(
      appBar: standardAppBar,
      body: webView,
    );
  }
}
