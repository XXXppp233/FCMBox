import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fcm_box/models/note.dart';

class JsonViewerPage extends StatelessWidget {
  final Note note;

  const JsonViewerPage({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> displayMap;
    if (note.rawJson != null) {
      displayMap = Map<String, dynamic>.from(note.rawJson!);
      // Update status fields to reflect current state
      displayMap['starred'] = note.starred;
      displayMap['trashed'] = note.trashed;
      displayMap['archived'] = note.archived;
    } else {
      displayMap = {
        'notification': {
          'title': note.notification.title,
          'body': note.notification.body,
        },
        'data': note.data,
        'starred': note.starred,
        'trashed': note.trashed,
        'archived': note.archived,
        'time': note.time,
        'priority': note.priority,
      };
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(displayMap);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('JSON Source'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(
          jsonString,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
      ),
    );
  }
}
