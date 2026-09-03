// Tests for the settings route and the generic provider selection route.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embla/common.dart';
import 'package:embla/prefs.dart' show Prefs;
import 'package:embla/provider_selection.dart';
import 'package:embla/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Report location permission as denied so enabling location sharing
    // in prefs doesn't try to start the (unavailable) location plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall call) async => 0);
    SharedPreferences.setMockInitialValues({});
    await Prefs().load();
    Prefs().setDefaults();
  });

  testWidgets('SettingsRoute contains the TTS and LLM provider rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    expect(find.text('Talgerving'), findsOneWidget);
    // Default providers are displayed using their human-readable labels
    expect(find.text(labelForValue(kTTSProviders, kDefaultTTSProvider)), findsOneWidget);
    // The LLM provider is reachable in a normal build, not just in debug:
    // choosing Gemini also switches voice turns to the fused path.
    expect(find.text('Mállíkansveita'), findsOneWidget);
    // Privacy note about third-party processing
    expect(find.text(kExternalProcessingNote), findsOneWidget);
    // The voice ID row follows the selected provider, and ElevenLabs is now
    // the default, so it is shown.
    expect(find.text('ElevenLabs rödd'), findsOneWidget);
    // The raw model name stays debug-only, and tests run in debug mode
    await tester.dragUntilVisible(
        find.text('Mállíkan'), find.byType(ListView), const Offset(0, -100));
    expect(find.text('Mállíkan'), findsOneWidget);
  });

  testWidgets('SettingsRoute shows ElevenLabs voice row when selected', (tester) async {
    Prefs().setStringForKey('tts_provider', 'elevenlabs');
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    expect(find.text('ElevenLabs rödd'), findsOneWidget);
  });

  testWidgets('Tapping the TTS row opens the provider selection route', (tester) async {
    // The ASR row is gone: Hreimur is the only engine in 2.0, so there is
    // nothing to choose between until it gains streaming.
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    await tester.tap(find.text('Talgerving'));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderSelectionRoute), findsOneWidget);
    // One list tile per TTS provider
    expect(find.byType(ListTile), findsNWidgets(kTTSProviders.length));
  });

  testWidgets('ProviderSelectionRoute writes the selected value to prefs', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: ProviderSelectionRoute(
      title: 'Talgerving',
      prefKey: 'tts_provider',
      options: kTTSProviders,
    )));
    await tester.pumpAndSettle();

    // Current value is marked with a checkmark
    expect(find.byIcon(Icons.done), findsOneWidget);

    await tester.tap(find.text(labelForValue(kTTSProviders, 'elevenlabs')));
    await tester.pumpAndSettle();

    expect(Prefs().stringForKey('tts_provider'), 'elevenlabs');
  });

  test('labelForValue falls back to the raw value', () {
    expect(labelForValue(kTTSProviders, 'icespeak'), 'Miðeind (Icespeak)');
    expect(labelForValue(kTTSProviders, 'nonexistent'), 'nonexistent');
    expect(labelForValue(kTTSProviders, null), '');
  });

  test('setDefaults sets all Embla 2.0 pipeline prefs', () {
    expect(Prefs().stringForKey('tts_provider'), kDefaultTTSProvider);
    expect(Prefs().stringForKey('llm_provider'), kDefaultLLMProvider);
    expect(Prefs().stringForKey('llm_model'), kDefaultOpenAIModel);
    expect(Prefs().stringForKey('elevenlabs_voice_id'), kDefaultElevenLabsVoiceID);
  });
}
