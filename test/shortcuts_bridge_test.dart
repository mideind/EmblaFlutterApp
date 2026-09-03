// The Shortcuts contract: every outcome is a dictionary with an `action`, and
// nothing ever throws, so a shortcut can always branch instead of dying.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embla/shortcuts_bridge.dart';
import 'package:embla/tools/device_actions_channel.dart' show kDeviceActionsChannelName;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel(kDeviceActionsChannelName);
  const StandardMethodCodec codec = StandardMethodCodec();

  /// Sends `runVoiceTurn` the way the native side does.
  Future<Map<Object?, Object?>?> invokeRunVoiceTurn() async {
    final ByteData? reply = await TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(const MethodCall('runVoiceTurn')),
      (_) {},
    );
    if (reply == null) return null;
    return codec.decodeEnvelope(reply) as Map<Object?, Object?>?;
  }

  tearDown(() => ShortcutsBridge().unregister());

  test('an answered turn comes back as action done', () async {
    ShortcutsBridge().register(() async {
      // The turn completes asynchronously, as a real one would.
      scheduleMicrotask(() => ShortcutsBridge()
          .reportReply(speech: 'Klukkan er fimm.', display: 'Klukkan er 17:00', transcript: 'hvað er klukkan'));
    });

    final res = await invokeRunVoiceTurn();
    expect(res!['action'], 'done');
    expect(res['speech'], 'Klukkan er fimm.');
    expect(res['display'], 'Klukkan er 17:00');
    expect(res['transcript'], 'hvað er klukkan');
  });

  test('a failure is action none with a reason, not an error', () async {
    ShortcutsBridge().register(() async {
      scheduleMicrotask(() => ShortcutsBridge().reportNone('Ekki næst samband við netið'));
    });

    // A shortcut that throws mid-run leaves the user with nothing, so this
    // path must still produce a branchable result.
    final res = await invokeRunVoiceTurn();
    expect(res!['action'], 'none');
    expect(res['reason'], 'Ekki næst samband við netið');
  });

  test('a turn that cannot even start still answers', () async {
    ShortcutsBridge().register(() async => throw StateError('no mic'));
    final res = await invokeRunVoiceTurn();
    expect(res!['action'], 'none');
    expect(res['reason'], contains('Ekki tókst að hefja hlustun'));
  });

  test('with nothing registered the shortcut is told so', () async {
    ShortcutsBridge().unregister();
    ShortcutsBridge().register(() async {});
    ShortcutsBridge().unregister();
    // No handler is installed now, so the platform message goes unanswered
    // rather than hanging the shortcut on a dead channel.
    expect(await invokeRunVoiceTurn(), isNull);
  });

  test('a message is handed to the shortcut as action send_message', () async {
    ShortcutsBridge().register(() async {
      scheduleMicrotask(() {
        expect(
            ShortcutsBridge().reportSendMessage(
                recipientName: 'María', phoneNumber: '5551234', body: 'ég kem heim'),
            isTrue);
        // The session still reports the spoken confirmation afterwards; the
        // shortcut must keep the message, not the confirmation.
        ShortcutsBridge().reportReply(speech: 'Ég sendi skilaboð.', display: 'Ég sendi skilaboð.');
      });
    });

    final res = await invokeRunVoiceTurn();
    expect(res!['action'], 'send_message');
    expect(res['recipient_name'], 'María');
    expect(res['phone_number'], '5551234');
    expect(res['body'], 'ég kem heim');
  });

  test('with no shortcut waiting a message is not taken', () async {
    ShortcutsBridge().register(() async {});
    expect(ShortcutsBridge().reportSendMessage(recipientName: 'María', body: 'hæ'), isFalse);
  });

  test('only the first report settles the turn', () async {
    ShortcutsBridge().register(() async {
      scheduleMicrotask(() {
        ShortcutsBridge().reportReply(speech: 'fyrsta', display: 'fyrsta');
        // handleDone fires after handleReply on every successful turn; it must
        // not overwrite the answer with "no answer".
        ShortcutsBridge().reportNone('Ekkert svar');
      });
    });

    final res = await invokeRunVoiceTurn();
    expect(res!['action'], 'done');
    expect(res['speech'], 'fyrsta');
  });
}
