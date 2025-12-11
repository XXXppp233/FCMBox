import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fcm_box/models/note.dart';

class JsonViewerPage extends StatefulWidget {
  final Note note;

  const JsonViewerPage({super.key, required this.note});

  @override
  State<JsonViewerPage> createState() => _JsonViewerPageState();
}

class _JsonViewerPageState extends State<JsonViewerPage> {
  bool _useCollapsibleView = true;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> displayMap;
    if (widget.note.rawJson != null) {
      displayMap = Map<String, dynamic>.from(widget.note.rawJson!);
      // Update status fields to reflect current state
      displayMap['starred'] = widget.note.starred;
      displayMap['trashed'] = widget.note.trashed;
      displayMap['archived'] = widget.note.archived;
    } else {
      displayMap = {
        'notification': {
          'title': widget.note.notification.title,
          'body': widget.note.notification.body,
        },
        'data': widget.note.data,
        'starred': widget.note.starred,
        'trashed': widget.note.trashed,
        'archived': widget.note.archived,
        'time': widget.note.time,
        'priority': widget.note.priority,
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
        actions: [
          IconButton(
            icon: Icon(
              _useCollapsibleView ? Icons.account_tree : Icons.data_object,
            ),
            tooltip: _useCollapsibleView ? 'Show Raw JSON' : 'Show Tree View',
            onPressed: () {
              setState(() {
                _useCollapsibleView = !_useCollapsibleView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _useCollapsibleView
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _JsonNode(keyName: 'root', value: displayMap),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                jsonString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
    );
  }
}

class _JsonNode extends StatelessWidget {
  final String keyName;
  final dynamic value;

  const _JsonNode({required this.keyName, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      final map = value as Map;
      if (map.isEmpty) {
        return _buildLeaf(context, keyName, '{}');
      }
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        title: Text(
          keyName,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        //subtitle: Text('{ ${map.length} items }'),
        initiallyExpanded: true,
        controlAffinity: ListTileControlAffinity.leading,
        childrenPadding: const EdgeInsets.only(left: 16.0),
        children: map.entries.map((entry) {
          return _JsonNode(keyName: entry.key.toString(), value: entry.value);
        }).toList(),
      );
    } else if (value is List) {
      final list = value as List;
      if (list.isEmpty) {
        return _buildLeaf(context, keyName, '[]');
      }
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        title: Text(
          keyName,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('[ ${list.length} items ]'),
        initiallyExpanded: true,
        controlAffinity: ListTileControlAffinity.leading,
        childrenPadding: const EdgeInsets.only(left: 16.0),
        children: list.asMap().entries.map((entry) {
          return _JsonNode(keyName: '[${entry.key}]', value: entry.value);
        }).toList(),
      );
    } else {
      return _buildLeaf(context, keyName, '$value');
    }
  }

  Widget _buildLeaf(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$key: ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
