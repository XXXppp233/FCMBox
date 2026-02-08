import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fcm_box/models/note.dart';

class JsonViewerPage extends StatelessWidget {
  final Note note;

  const JsonViewerPage({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              note.overview,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50, // Approx 2 lines height
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          note.service,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateTime.fromMillisecondsSinceEpoch(
                            note.timestamp,
                          ).toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (note.image != null && note.image!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          note.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 32),
            // Data Renderer
            _buildDataRenderer(context, note.data),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRenderer(BuildContext context, dynamic data) {
    dynamic processedData = data;
    if (processedData is String) {
      try {
        processedData = json.decode(processedData);
      } catch (_) {
        // Not a JSON string, keep as is
      }
    }

    if (processedData is Map) {
      if (processedData.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: processedData.entries.map<Widget>((entry) {
          final key = entry.key.toString();
          final value = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildValueRenderer(context, value),
              ),
            ],
          );
        }).toList(),
      );
    } else if (processedData is List) {
      return _buildListRenderer(context, processedData);
    } else {
      return _buildParagraphRenderer(context, processedData);
    }
  }

  Widget _buildValueRenderer(BuildContext context, dynamic value) {
    if (value is List) {
      return _buildListRenderer(context, value);
    } else {
      return _buildParagraphRenderer(context, value);
    }
  }

  Widget _buildListRenderer(BuildContext context, List list) {
    if (list.isEmpty) return const Text('Empty List');
    int index = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map((item) {
        final current = index++;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$current. ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Expanded(child: Text(item.toString())),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParagraphRenderer(BuildContext context, dynamic value) {
    return Text(
      '\t\t${value.toString()}', // Simple indentation
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
