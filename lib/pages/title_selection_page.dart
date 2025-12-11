import 'package:flutter/material.dart';
import 'package:fcm_box/localization.dart';

class TitleSelectionPage extends StatefulWidget {
  final List<String> allTitles;
  final String? selectedTitle;

  const TitleSelectionPage({
    super.key,
    required this.allTitles,
    this.selectedTitle,
  });

  @override
  State<TitleSelectionPage> createState() => _TitleSelectionPageState();
}

class _TitleSelectionPageState extends State<TitleSelectionPage> {
  late List<String> _filteredTitles;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTitles = widget.allTitles;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTitles = widget.allTitles
          .where((title) => title.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText:
                AppLocalizations.of(context)?.translate('search_title') ??
                'Search Title',
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
          ),
          autofocus: true,
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredTitles.length,
        itemBuilder: (context, index) {
          final title = _filteredTitles[index];
          final isSelected = title == widget.selectedTitle;
          return ListTile(
            title: Text(title),
            trailing: isSelected ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(context).pop(title);
            },
          );
        },
      ),
    );
  }
}
