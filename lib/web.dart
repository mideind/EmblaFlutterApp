import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutRoute extends StatelessWidget {
  final initialURL = "https://embla.is/about.html";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        backgroundColor: Colors.transparent,
        bottomOpacity: 0.0,
        elevation: 0.0,
      ),
      body: WebView(
        initialUrl: initialURL,
        navigationDelegate: (NavigationRequest request) {
          if (request.url != initialURL) {
            launch(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}

class InstructionsRoute extends StatelessWidget {
  final initialURL = "https://embla.is/instructions.html";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        backgroundColor: Colors.transparent,
        bottomOpacity: 0.0,
        elevation: 0.0,
      ),
      body: WebView(
        initialUrl: initialURL,
        navigationDelegate: (NavigationRequest request) {
          if (request.url != initialURL) {
            launch(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}

class PrivacyRoute extends StatelessWidget {
  final initialURL = "https://embla.is/privacy.html";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        backgroundColor: Colors.transparent,
        bottomOpacity: 0.0,
        elevation: 0.0,
      ),
      body: WebView(
        initialUrl: initialURL,
        navigationDelegate: (NavigationRequest request) {
          if (request.url != initialURL) {
            launch(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}
