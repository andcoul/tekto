import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/api/sse.dart';

/// Splits [text] into byte chunks of [size] to mimic network packets.
Stream<List<int>> _bytes(String text, int size) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

const _body = 'event: text\ndata: {"text":"Été "}\n\n'
    'event: text\ndata: {"text":"💪 go"}\n\n'
    'event: done\ndata: {"message_id":"m-1","plan_change_proposed":null,"quota_remaining":2}\n\n';

void main() {
  test('parses named events with JSON data, whatever the packet size', () async {
    for (final size in [1, 3, 7, 64, 4096]) {
      final events = await parseSse(_bytes(_body, size)).toList();
      expect(events.map((e) => e.event), ['text', 'text', 'done'], reason: 'size $size');
      expect(events[0].data['text'], 'Été ');
      expect(events[1].data['text'], '💪 go');
      expect(events[2].data['quota_remaining'], 2);
    }
  });

  test('handles CRLF line endings and ignores comments', () async {
    final body = ': keep-alive\r\nevent: error\r\ndata: {"error":"AI_UNAVAILABLE"}\r\n\r\n';
    final events = await parseSse(_bytes(body, 5)).toList();
    expect(events.single.event, 'error');
    expect(events.single.data['error'], 'AI_UNAVAILABLE');
  });

  test('an event without a name is "message"; multi-line data is joined', () async {
    final events = await parseSse(_bytes('data: {"a":\ndata: 1}\n\n', 4)).toList();
    expect(events.single.event, 'message');
    expect(events.single.data['a'], 1);
  });

  test('a final event without a trailing blank line is still delivered', () async {
    final events = await parseSse(_bytes('event: done\ndata: {"ok":true}', 3)).toList();
    expect(events.single.event, 'done');
  });
}
