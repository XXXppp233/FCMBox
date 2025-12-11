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

class _JsonNode extends StatefulWidget {
  final String keyName;
  final dynamic value;

  const _JsonNode({required this.keyName, required this.value});

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.value is Map) {
      final map = widget.value as Map;
      if (map.isEmpty) {
        return _buildLeaf(context, widget.keyName, '{}');
      }
      return _buildExpandable(
        context,
        widget.keyName,
        '{ ${map.length} items }',
        map.entries.map((entry) {
          return _JsonNode(keyName: entry.key.toString(), value: entry.value);
        }).toList(),
      );
    } else if (widget.value is List) {
      final list = widget.value as List;
      if (list.isEmpty) {
        return _buildLeaf(context, widget.keyName, '[]');
      }
      return _buildExpandable(
        context,
        widget.keyName,
        '[ ${list.length} items ]',
        list.asMap().entries.map((entry) {
          return _JsonNode(keyName: '[${entry.key}]', value: entry.value);
        }).toList(),
      );
    } else {
      return _buildLeaf(context, widget.keyName, '${widget.value}');
    }
  }

  Widget _buildExpandable(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
      ],
    );
  }

  Widget _buildLeaf(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 24.0),
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
