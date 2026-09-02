// Tests for the platform-independent tool set.

import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/llm/llm_client.dart' show ToolCall;
import 'package:embla/tools/default_tools.dart';
import 'package:embla/tools/tool.dart';

final DateTime kNow = DateTime.utc(2026, 9, 2, 14, 35);

ToolContext ctx({List<double>? location, bool privateMode = false}) => ToolContext(
      now: kNow,
      location: location,
      privateMode: privateMode,
      clientID: 'device-1',
      clientType: 'ios-flutter',
      clientVersion: '1.4.0',
    );

http.Response _jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('every default tool', () {
    final ToolRegistry registry =
        buildDefaultToolRegistry(serverURL: 'https://api.mideind.is', apiKey: 'k');

    test('is registered', () {
      expect(registry.tools.map((t) => t.name).toSet(),
          {'greynir_query', 'get_datetime', 'get_location', 'open_url'});
    });

    test('has a strict-compatible schema and an Icelandic description', () {
      for (final Tool t in registry.tools) {
        final Map<String, dynamic> p = t.parameters;
        expect(p['type'], 'object', reason: t.name);
        expect(p['additionalProperties'], false, reason: t.name);
        final Map properties = p['properties'] as Map;
        final List required = p['required'] as List;
        expect(required.toSet(), properties.keys.toSet(), reason: t.name);
        expect(t.description, isNotEmpty, reason: t.name);
        for (final dynamic prop in properties.values) {
          expect((prop as Map)['description'], isNotNull, reason: t.name);
        }
      }
    });

    test('turns an unknown tool name into a failure', () async {
      final r = await registry.dispatch(
          const ToolCall(id: 'c', name: 'nope', arguments: {}), ctx());
      expect(r.ok, false);
      expect(r.data['error'], contains('Óþekkt verkfæri'));
    });
  });

  group('greynir_query', () {
    test('posts the query with client info and location', () async {
      Map<String, dynamic>? sent;
      Map<String, String>? headers;
      Uri? url;

      final tool = GreynirQueryTool(
        serverURL: 'https://api.mideind.is',
        apiKey: 'secret',
        client: MockClient((http.Request req) async {
          url = req.url;
          headers = req.headers;
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _jsonResponse({
            'valid': true,
            'answer': '12°C og skýjað',
            'source': 'Vegagerðin',
            'qtype': 'Weather',
            'image': 'https://greynir.is/img/weather.png',
            'open_url': 'https://vedur.is/',
          });
        }),
      );

      final r = await tool.call(
          {'q': 'hvernig er veðrið'}, ctx(location: [64.1466, -21.9426]));

      expect(url.toString(), 'https://api.mideind.is/rat/v1/query');
      expect(headers?['x-api-key'], 'secret');
      expect(sent!['q'], 'hvernig er veðrið');
      expect(sent!['tts'], false);
      final Map options = sent!['options'] as Map;
      expect(options['client_id'], 'device-1');
      expect(options['client_type'], 'ios-flutter');
      expect(options['client_version'], '1.4.0');
      expect(options['latitude'], 64.1466);
      expect(options['longitude'], -21.9426);

      expect(r.ok, true);
      expect(r.data['valid'], true);
      expect(r.data['answer'], '12°C og skýjað');
      expect(r.data['source'], 'Vegagerðin');
      expect(r.data['qtype'], 'Weather');
      expect(r.imageURL, 'https://greynir.is/img/weather.png');
      expect(r.openURL.toString(), 'https://vedur.is/');
    });

    test('omits the location in private mode', () async {
      Map<String, dynamic>? sent;
      final tool = GreynirQueryTool(
        serverURL: 'https://api.mideind.is',
        apiKey: 'secret',
        client: MockClient((http.Request req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _jsonResponse({'valid': false});
        }),
      );

      await tool.call(
          {'q': 'veðrið'}, ctx(location: [64.1466, -21.9426], privateMode: true));

      final Map options = sent!['options'] as Map;
      expect(options.containsKey('latitude'), false);
      expect(options.containsKey('longitude'), false);
    });

    test('reports valid:false so the model can answer itself', () async {
      final tool = GreynirQueryTool(
        serverURL: 'https://api.mideind.is',
        apiKey: 'k',
        client: MockClient((_) async => _jsonResponse({'valid': false, 'answer': null})),
      );
      final r = await tool.call({'q': 'hver skrifaði Njálu'}, ctx());
      expect(r.ok, true);
      expect(jsonDecode(r.toJson()), {'ok': true, 'valid': false});
    });

    test('reports a failure on a server error', () async {
      final tool = GreynirQueryTool(
        serverURL: 'https://api.mideind.is',
        apiKey: 'k',
        client: MockClient((_) async => _jsonResponse({'error': 'nope'}, 500)),
      );
      final r = await tool.call({'q': 'veðrið'}, ctx());
      expect(r.ok, false);
      expect(r.data['error'], contains('500'));
    });

    test('rejects a missing query', () async {
      final tool = GreynirQueryTool(
        serverURL: 'https://api.mideind.is',
        apiKey: 'k',
        client: MockClient((_) async => _jsonResponse({'valid': true, 'answer': 'x'})),
      );
      final r = await tool.call({}, ctx());
      expect(r.ok, false);
    });
  });

  group('get_datetime', () {
    test('returns ISO and Icelandic text', () async {
      final r = await DateTimeTool().call({}, ctx());
      expect(r.ok, true);
      expect(r.data['iso'], '2026-09-02T14:35:00.000Z');
      expect(r.data['text'], 'miðvikudagur 2. september 2026, 14:35');
      expect(r.data['weekday'], 'miðvikudagur');
      expect(r.data['timezone'], 'Atlantic/Reykjavik');
    });
  });

  group('get_location', () {
    test('returns coordinates when known', () async {
      final r = await LocationTool().call({}, ctx(location: [64.1466, -21.9426]));
      expect(r.data['known'], true);
      expect(r.data['latitude'], 64.1466);
      expect(r.data['longitude'], -21.9426);
    });

    test('returns known:false when unknown or private', () async {
      expect((await LocationTool().call({}, ctx())).data['known'], false);
      final private = await LocationTool()
          .call({}, ctx(location: [64.1466, -21.9426], privateMode: true));
      expect(private.data['known'], false);
      expect(private.data.containsKey('latitude'), false);
    });
  });

  group('open_url', () {
    test('accepts an absolute https URL and ends the turn', () async {
      final r = await OpenURLTool().call({'url': 'https://embla.is/about.html'}, ctx());
      expect(r.ok, true);
      expect(r.openURL.toString(), 'https://embla.is/about.html');
      expect(r.endsTurn, true);
    });

    test('rejects relative, empty and non-web URLs', () async {
      for (final String bad in ['', '/about.html', 'embla.is', 'javascript:alert(1)', 'file:///etc/passwd']) {
        final r = await OpenURLTool().call({'url': bad}, ctx());
        expect(r.ok, false, reason: bad);
      }
    });
  });
}
