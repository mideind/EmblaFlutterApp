// Tests for the structured final reply contract.

import 'package:flutter_test/flutter_test.dart';

import 'package:embla/assistant/reply.dart';

void main() {
  group('AssistantReply.schema', () {
    test('is strict-compatible', () {
      expect(AssistantReply.schema['type'], 'object');
      expect(AssistantReply.schema['additionalProperties'], false);
      final Map properties = AssistantReply.schema['properties'] as Map;
      final List required = AssistantReply.schema['required'] as List;
      expect(required.toSet(), properties.keys.toSet());
      expect(required.toSet(), {'kind', 'speech', 'display'});
      expect((properties['kind'] as Map)['enum'],
          ['answer', 'action_done', 'clarify', 'unknown']);
    });
  });

  group('AssistantReply.parse', () {
    test('parses well-formed JSON', () {
      final r = AssistantReply.parse(
          '{"kind":"answer","speech":"Það er tíu stig í Reykjavík.",'
          '"display":"10°C í Reykjavík (Vegagerðin)."}');
      expect(r.kind, ReplyKind.answer);
      expect(r.speech, 'Það er tíu stig í Reykjavík.');
      expect(r.display, '10°C í Reykjavík (Vegagerðin).');
    });

    test('parses every kind, including action_done', () {
      expect(AssistantReply.parse('{"kind":"action_done","speech":"a","display":"b"}').kind,
          ReplyKind.actionDone);
      expect(AssistantReply.parse('{"kind":"clarify","speech":"a","display":"b"}').kind,
          ReplyKind.clarify);
      expect(AssistantReply.parse('{"kind":"unknown","speech":"a","display":"b"}').kind,
          ReplyKind.unknown);
      expect(AssistantReply.parse('{"kind":"answer","speech":"a","display":"b"}').kind,
          ReplyKind.answer);
    });

    test('tolerates surrounding whitespace', () {
      final r = AssistantReply.parse('\n  {"kind":"unknown","speech":"a","display":"b"}\n');
      expect(r.kind, ReplyKind.unknown);
    });

    test('treats non-JSON text as a plain answer', () {
      final r = AssistantReply.parse('Reykjavík er höfuðborg Íslands.');
      expect(r.kind, ReplyKind.answer);
      expect(r.speech, 'Reykjavík er höfuðborg Íslands.');
      expect(r.display, 'Reykjavík er höfuðborg Íslands.');
    });

    test('falls back to answer on an unknown kind value', () {
      final r = AssistantReply.parse('{"kind":"eitthvað","speech":"a","display":"b"}');
      expect(r.kind, ReplyKind.answer);
    });

    test('fills in a missing field from the other one', () {
      final a = AssistantReply.parse('{"kind":"answer","display":"aðeins skjátexti"}');
      expect(a.speech, 'aðeins skjátexti');
      final b = AssistantReply.parse('{"kind":"answer","speech":"aðeins tal"}');
      expect(b.display, 'aðeins tal');
    });

    test('treats a bare JSON array as plain text', () {
      final r = AssistantReply.parse('[1,2,3]');
      expect(r.kind, ReplyKind.answer);
      expect(r.speech, '[1,2,3]');
    });

    test('handles an empty string', () {
      final r = AssistantReply.parse('');
      expect(r.kind, ReplyKind.answer);
      expect(r.speech, '');
    });
  });
}
