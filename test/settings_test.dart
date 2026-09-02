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

  testWidgets('SettingsRoute contains ASR and TTS provider rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    expect(find.text('Talgreining'), findsOneWidget);
    expect(find.text('Talgerving'), findsOneWidget);
    // Default providers are displayed using their human-readable labels
    expect(find.text(labelForValue(kASRProviders, kDefaultASRProvider)), findsOneWidget);
    expect(find.text(labelForValue(kTTSProviders, kDefaultTTSProvider)), findsOneWidget);
    // Privacy note about third-party processing
    expect(find.text(kExternalProcessingNote), findsOneWidget);
    // ElevenLabs voice row is only shown when ElevenLabs is selected
    expect(find.text('ElevenLabs rödd'), findsNothing);
    // Language model row is debug-only, and tests run in debug mode
    await tester.dragUntilVisible(
        find.text('Mállíkan'), find.byType(ListView), const Offset(0, -100));
    expect(find.text('Mállíkan'), findsOneWidget);
  });

  testWidgets('SettingsRoute shows ElevenLabs voice row when selected', (tester) async {
    Prefs().setStringForKey('tts_provider', 'elevenlabs');
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    expect(find.text('ElevenLabs rödd'), findsOneWidget);
  });

  testWidgets('Tapping the ASR row opens the provider selection route', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsRoute()));

    await tester.tap(find.text('Talgreining'));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderSelectionRoute), findsOneWidget);
    // One list tile per ASR provider
    expect(find.byType(ListTile), findsNWidgets(kASRProviders.length));
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
    expect(Prefs().stringForKey('asr_provider'), kDefaultASRProvider);
    expect(Prefs().stringForKey('tts_provider'), kDefaultTTSProvider);
    expect(Prefs().stringForKey('llm_provider'), kDefaultLLMProvider);
    expect(Prefs().stringForKey('llm_model'), kDefaultOpenAIModel);
    expect(Prefs().stringForKey('elevenlabs_voice_id'), kDefaultElevenLabsVoiceID);
  });
}
