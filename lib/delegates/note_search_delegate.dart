import 'package:flutter/material.dart';
import 'package:fcm_box/models/note.dart';
import 'package:fcm_box/l10n/app_localizations.dart';
import 'package:fcm_box/pages/json_viewer_page.dart';

class NoteSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Note> allNotes;
  final String? _searchFieldLabel;

  NoteSearchDelegate({required this.allNotes, String? searchFieldLabel}) : _searchFieldLabel = searchFieldLabel;

  @override
  String? get searchFieldLabel => _searchFieldLabel;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final lowerQuery = query.toLowerCase();

    final titleResults = allNotes.where((note) {
      return note.service.toLowerCase().contains(lowerQuery);
    }).toList();

    final contentResults = allNotes.where((note) {
      final overviewMatch = note.overview.toLowerCase().contains(lowerQuery);
      final dataMatch = note.data != null && note.data.toString().toLowerCase().contains(lowerQuery);
      return overviewMatch || dataMatch;
    }).toList();

    if (titleResults.isEmpty && contentResults.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)?.no_results ?? 'No results'),
      );
    }

    return ListView(
      children: [
        if (titleResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              AppLocalizations.of(context)?.search_by_title ?? 'Search by Services',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...titleResults.map((note) => ListTile(
                title: Text(note.service, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  close(context, {'type': 'service', 'value': note.service});
                },
              )),
        ],
        if (contentResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              AppLocalizations.of(context)?.search_by_content ?? 'Search by Content',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...contentResults.map((note) => ListTile(
                title: Text(note.overview, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(note.service, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JsonViewerPage(note: note),
                    ),
                  );
                },
              )),
        ],
      ],
    );
  }
}
