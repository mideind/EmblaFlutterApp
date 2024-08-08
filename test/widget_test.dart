// These are the tests for the project's widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'; // ignore: depend_on_referenced_packages

// import 'package:embla/main.dart';
import 'package:embla/menu.dart';
// import 'package:embla/session.dart';
import 'package:embla/settings.dart';
import 'package:embla/info.dart';
import 'package:embla/voices.dart';
import 'package:embla/web.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  // main.dart
//   testWidgets('EmblaApp contains SessionRoute', (tester) async {
//     await tester.pumpWidget(
//       EmblaApp(),
//     );
//     expect(find.byType(SessionRoute), findsOneWidget);
//   });

  // menu.dart
  testWidgets('MenuRoute contains at least 4 ListTiles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MenuRoute(),
      ),
    );
    expect(find.byType(ListTile), findsAtLeastNWidgets(4));
  });

  // session.dart
//   testWidgets('SessionRoute contains two IconButtons', (tester) async {
//     await tester.pumpWidget(
//       MaterialApp(
//         home: SessionRoute(),
//       ),
//     );
//     expect(find.byType(IconButton), findsNWidgets(2));
//   });

  // settings.dart
  testWidgets('SettingsRoute contains ListView and at least 2 Switches', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsRoute(),
      ),
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SettingsSwitchWidget), findsAtLeastNWidgets(2));
  });

  // version.dart
  testWidgets('VersionRoute contains ListView with at least 4 items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VersionRoute(),
      ),
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SettingsAsyncLabelValueWidget), findsAtLeastNWidgets(4));
  });

  // voices.dart
  testWidgets('VoicesRoute contains ListView and at least 2 items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceSelectionRoute(),
      ),
    );
    // Give async builder time to complete
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsAtLeastNWidgets(2));
  });

  // web.dart
  testWidgets('WebViewRoute contains InAppWebView', (tester) async {
    preloadHTMLDocuments();
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewRoute(initialURL: "https://mideind.is"),
      ),
    );
    expect(find.byType(InAppWebView), findsOneWidget);
  });
}
