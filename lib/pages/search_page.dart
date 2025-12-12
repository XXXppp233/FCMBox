import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fcm_box/models/note.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/pages/json_viewer_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _searchHistory = [];
  List<Note> _allNotes = [];
  List<Note> _titleResults = [];
  List<Note> _contentResults = [];
  bool _isSearching = false;
  bool _isTitleExpanded = true;
  bool _isContentExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes');
    if (notesJson != null) {
      final List<dynamic> data = json.decode(notesJson);
      setState(() {
        _allNotes = data.map((json) => Note.fromJson(json)).toList();
      });
    } else {
      setState(() {
        _allNotes = [];
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? history = prefs.getStringList('search_history');
      if (history != null) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  void _addHistory(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    });
    _saveHistory();
  }

  void _removeHistory(String query) {
    setState(() {
      _searchHistory.remove(query);
    });
    _saveHistory();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _titleResults = [];
        _contentResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _titleResults = _allNotes.where((note) {
        return note.notification.title.toLowerCase().contains(query);
      }).toList();
      _contentResults = _allNotes.where((note) {
        // Exclude if already in title results to avoid duplicates?
        // Or show in both? Usually show in both or prioritize.
        // User said "Search by Title" and "Search by Content".
        // If a note matches both, it might appear in both.
        // Let's keep it simple and allow duplicates for now, or exclude.
        // If I exclude, I should check if it's in _titleResults.
        // But "Search by Content" implies the content matches.
        // Let's allow duplicates as they are distinct matches.
        return note.notification.body.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _onSubmitted(String query) {
    _addHistory(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black54,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText:
                AppLocalizations.of(context)?.translate('search_hint') ??
                'Search',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600],
            ),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _onSubmitted,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: isDark ? Colors.white : Colors.black54,
              ),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: _isSearching ? _buildSearchResults() : _buildSearchHistory(),
    );
  }

  Widget _buildSearchHistory() {
    return ListView.builder(
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final history = _searchHistory[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(history),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _removeHistory(history),
          ),
          onTap: () {
            _searchController.text = history;
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: history.length),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_titleResults.isEmpty && _contentResults.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.translate('no_results') ?? 'No results',
        ),
      );
    }

    return ListView(
      children: [
        if (_titleResults.isNotEmpty)
          _buildSection(
            title:
                AppLocalizations.of(context)?.translate('search_by_title') ??
                'Search by Title',
            results: _titleResults,
            isExpanded: _isTitleExpanded,
            onToggle: () {
              setState(() {
                _isTitleExpanded = !_isTitleExpanded;
              });
            },
          ),
        if (_contentResults.isNotEmpty)
          _buildSection(
            title:
                AppLocalizations.of(context)?.translate('search_by_content') ??
                'Search by Content',
            results: _contentResults,
            isExpanded: _isContentExpanded,
            onToggle: () {
              setState(() {
                _isContentExpanded = !_isContentExpanded;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Note> results,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  color: Colors.grey,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Column(
            children: results.map((note) {
              return ListTile(
                title: Text(
                  note.notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  note.notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JsonViewerPage(note: note),
                    ),
                  );
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
