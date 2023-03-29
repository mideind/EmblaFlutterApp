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

/// Documentation web views.

import 'package:flutter/material.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

import './theme.dart' show standardAppBar;
import './common.dart' show dlog;

const String kDocsDir = 'docs';
const String kLoadingHTMLFilePath = "$kDocsDir/loading.html";
const String kLoadingDarkHTMLFilePath = "$kDocsDir/loading_dark.html";

/// Standard web view route used for displaying documentation HTML files.
class WebViewRoute extends StatefulWidget {
  final String initialURL;

  const WebViewRoute({Key? key, required this.initialURL}) : super(key: key);

  @override
  WebViewRouteState createState() => WebViewRouteState();
}

class WebViewRouteState extends State<WebViewRoute> {
  /// Path to local asset with same filename as remote HTML document.
  String _fallbackAssetForURL(String url) {
    final Uri uri = Uri.parse(url);
    return "$kDocsDir/${uri.pathSegments.last}";
  }

  /// Add dark=1 query parameter to URL.
  /// This param is used to style the HTML document for dark mode via JS.
  String _darkURLForURL(String url) {
    return "$url?dark=1";
  }

  /// Fall back to local HTML document if error comes
  /// up when fetching document from remote server.
  void errHandler(InAppWebViewController controller, Uri? url, int errCode, String desc) async {
    dlog("Page load error for $url: $errCode, $desc");
    final String path = _fallbackAssetForURL(url.toString());
    dlog("Falling back to local asset $path");
    setState(() {
      controller.loadFile(assetFilePath: path);
    });
  }

  /// Handle clicks on links in HTML documentation.
  /// These links should be opened in an external browser to
  /// avoid screwing with the navigation stack of the app.
  Future<NavigationActionPolicy> urlClickHandler(
      InAppWebViewController controller, NavigationAction action) async {
    final URLRequest req = action.request;
    final String urlStr = req.url.toString();
    final String fallbackFilename = _fallbackAssetForURL(urlStr);

    if (urlStr.startsWith(widget.initialURL) == false &&
        urlStr.endsWith(fallbackFilename) == false) {
      dlog("Opening external URL: ${req.url}");
      await launchUrl(req.url!, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  /// Create web view that initially presents a "loading" document with
  /// a progress indicator. Then immediately fetch the actual remote document.
  /// Falls back to loading local bundled HTML document on network error.
  /// This means that at least *some* version of the document can be viewed
  /// even when the device is offline.
  InAppWebView _buildWebView(BuildContext context) {
    final darkMode = (MediaQuery.of(context).platformBrightness == Brightness.dark);
    final loadingURL = darkMode ? kLoadingDarkHTMLFilePath : kLoadingHTMLFilePath;
    final finalURL = darkMode ? _darkURLForURL(widget.initialURL) : widget.initialURL;

    final webViewOpts = InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      transparentBackground: true,
    ));

    // Create and configure web view
    return InAppWebView(
      initialFile: loadingURL,
      initialUrlRequest: URLRequest(url: Uri.parse(finalURL)),
      initialOptions: webViewOpts,
      onLoadStart: (InAppWebViewController controller, Uri? uri) {
        dlog("Loading URL ${uri.toString()}");
      },
      onLoadStop: (InAppWebViewController controller, Uri? uri) async {
        if (uri.toString().endsWith(loadingURL)) {
          // Loading of initial "loading" document is complete.
          // Now load the actual remote document.
          setState(() {
            controller.loadUrl(urlRequest: URLRequest(url: Uri.parse(finalURL)));
          });
        }
      },
      onLoadError: errHandler,
      onLoadHttpError: errHandler,
      shouldOverrideUrlLoading: urlClickHandler,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: standardAppBar,
      body: _buildWebView(context),
    );
  }
}
