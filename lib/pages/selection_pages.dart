import 'package:flutter/material.dart';
import 'package:fcm_box/localization.dart';

class GenericSelectionPage extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selectedOption;

  const GenericSelectionPage({
    super.key,
    required this.title,
    required this.options,
    this.selectedOption,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == selectedOption;
                return ListTile(
                  title: Text(
                    AppLocalizations.of(
                          context,
                        )?.translate(option.replaceAll(' ', '_')) ??
                        option,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context, option);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MultiSelectionPage extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;

  const MultiSelectionPage({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
  });

  @override
  State<MultiSelectionPage> createState() => _MultiSelectionPageState();
}

class _MultiSelectionPageState extends State<MultiSelectionPage> {
  late Set<String> _currentSelected;

  @override
  void initState() {
    super.initState();
    _currentSelected = Set.from(widget.selectedOptions);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, _currentSelected);
                  },
                  child: Text(
                    AppLocalizations.of(context)?.translate('done') ?? 'Done',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final isSelected = _currentSelected.contains(option);
                return CheckboxListTile(
                  title: Text(
                    AppLocalizations.of(context)?.translate(option) ?? option,
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _currentSelected.add(option);
                      } else {
                        _currentSelected.remove(option);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
