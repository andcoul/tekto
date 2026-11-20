import 'dart:async';
import 'dart:convert';

/// One server-sent event whose `data` is a JSON object (contracts/backend-api.md
/// `POST /coach-message`).
class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;
}

/// Decodes a `text/event-stream` body into events. Bytes are decoded as UTF-8 across packet
/// boundaries; comment lines (`:`) and events with non-JSON data are skipped.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var name = 'message';
  final data = <String>[];

  SseEvent? flush() {
    if (data.isEmpty) {
      name = 'message';
      return null;
    }
    final raw = data.join('\n');
    final event = name;
    data.clear();
    name = 'message';
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? SseEvent(event, decoded) : null;
    } on FormatException {
      return null;
    }
  }

  await for (final line in bytes.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      final event = flush();
      if (event != null) yield event;
    } else if (line.startsWith(':')) {
      continue;
    } else if (line.startsWith('event:')) {
      name = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    }
  }
  final last = flush();
  if (last != null) yield last;
}
