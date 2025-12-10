import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:fcm_box/models/note.dart';
import 'package:fcm_box/pages/settings_page.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fcm_box/services/google_drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  await GoogleDriveService().init();

  final prefs = await SharedPreferences.getInstance();
  final useMonet = prefs.getBool('use_monet') ?? false;
  final colorValue = prefs.getInt('theme_color') ?? Colors.blue.value;
  themeSettingsNotifier.value = ThemeSettings(useMonet, colorValue);

  final languageCode = prefs.getString('language_code');
  if (languageCode != null) {
    localeSettingsNotifier.value = LocaleSettings(Locale(languageCode));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocaleSettings>(
      valueListenable: localeSettingsNotifier,
      builder: (context, localeSettings, child) {
        return ValueListenableBuilder<ThemeSettings>(
          valueListenable: themeSettingsNotifier,
          builder: (context, settings, child) {
            return DynamicColorBuilder(
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                ColorScheme lightScheme;
                ColorScheme darkScheme;

                if (settings.useMonet && lightDynamic != null && darkDynamic != null) {
                  lightScheme = lightDynamic.harmonized();
                  darkScheme = darkDynamic.harmonized();
                } else {
                  lightScheme = ColorScheme.fromSeed(
                    seedColor: Color(settings.colorValue),
                  );
                  darkScheme = ColorScheme.fromSeed(
                    seedColor: Color(settings.colorValue),
                    brightness: Brightness.dark,
                  );
                }

                return MaterialApp(
                  title: 'FCM Box',
                  locale: localeSettings.locale,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', ''),
                    Locale('zh', ''),
                  ],
                  theme: ThemeData(
                    colorScheme: lightScheme,
                    useMaterial3: true,
                  ),
                  darkTheme: ThemeData(
                    colorScheme: darkScheme,
                    useMaterial3: true,
                  ),
                  home: const MyHomePage(title: 'FCM Box'),
                );
              },
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  Set<String> _filterLabels = {}; // 'starred', 'trashed', 'archived'
  String? _filterPriority; // 'high', 'normal', 'low'
  String? _filterTime; // '1 week', '1 month', '3 months'
  String? _filterTitle;
  String _leftSwipeAction = 'archive';
  String _rightSwipeAction = 'delete';
  String _sortOption = 'time';
  bool _isReverse = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _leftSwipeAction = prefs.getString('left_swipe_action') ?? 'archive';
      _rightSwipeAction = prefs.getString('right_swipe_action') ?? 'delete';
    });
  }

  Future<void> _loadNotes() async {
    try {
      final String response = await rootBundle.loadString('assets/data.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _notes = data.map((json) => Note.fromJson(json)).toList();
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        // Label filter
        if (_filterLabels.isEmpty) {
          if (note.trashed || note.archived) return false;
        } else {
          bool match = false;
          if (_filterLabels.contains('starred') && note.starred) match = true;
          if (_filterLabels.contains('trashed') && note.trashed) match = true;
          if (_filterLabels.contains('archived') && note.archived) match = true;
          if (!match) return false;
        }

        // Priority filter
        if (_filterPriority != null && note.priority != _filterPriority) return false;

        // Time filter
        if (_filterTime != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(note.time * 1000);
          final now = DateTime.now();
          final diff = now.difference(date).inDays;
          if (_filterTime == '1 week' && diff > 7) return false;
          if (_filterTime == '1 month' && diff > 30) return false;
          if (_filterTime == '3 months' && diff > 90) return false;
        }

        // Title filter
        if (_filterTitle != null && note.notification.title != _filterTitle) return false;

        return true;
      }).toList();

      if (_sortOption == 'time') {
        _filteredNotes.sort((a, b) => _isReverse
            ? a.time.compareTo(b.time)
            : b.time.compareTo(a.time));
      } else if (_sortOption == 'name') {
        _filteredNotes.sort((a, b) => _isReverse
            ? b.notification.title.compareTo(a.notification.title)
            : a.notification.title.compareTo(b.notification.title));
      }
    });
  }

  Future<Set<String>?> _showMultiSelectionSheet(
      BuildContext context, String title, List<String> options, Set<String> selectedOptions) {
    final bool isLarge = options.length > 5;
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: isLarge,
      useSafeArea: true,
      shape: isLarge
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: isLarge ? 1.0 : 0.5,
              minChildSize: isLarge ? 1.0 : 0.5,
              maxChildSize: 1.0,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title,
                              style: Theme.of(context).textTheme.titleLarge),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, selectedOptions);
                            },
                            child: Text(AppLocalizations.of(context)?.translate('done') ?? 'Done'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected = selectedOptions.contains(option);
                          return CheckboxListTile(
                            title: Text(AppLocalizations.of(context)?.translate(option) ?? option),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedOptions.add(option);
                                } else {
                                  selectedOptions.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<String?> _showSelectionSheet(
      BuildContext context, String title, List<String> options) {
    final bool isLarge = options.length > 5;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: isLarge,
      useSafeArea: true,
      shape: isLarge
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: isLarge ? 1.0 : 0.5,
          minChildSize: isLarge ? 1.0 : 0.5,
          maxChildSize: 1.0,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return ListTile(
                        title: Text(AppLocalizations.of(context)?.translate(option) ?? option),
                        onTap: () {
                          Navigator.pop(context, option);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyFcmToken() async {
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
      fcmToken = "Error getting token";
    }

    if (fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: fcmToken));
      if (mounted) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)?.translate('fcm_token_copied') ?? "FCM Token copied to clipboard",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.black,
            textColor: Colors.white,
            fontSize: 16.0,
            webPosition: 'center');
      }
    }
  }

  void _sortByDate() {
    setState(() {
      if (_sortOption == 'time') {
        _isReverse = !_isReverse;
      } else {
        _sortOption = 'time';
        _isReverse = false;
      }
      _applyFilters();
    });
    Fluttertoast.showToast(
        msg: _isReverse 
          ? (AppLocalizations.of(context)?.translate('sorted_by_time_reversed') ?? "Sorted by time, reversed") 
          : (AppLocalizations.of(context)?.translate('sorted_by_time') ?? "Sorted by time"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
        webPosition: 'center');
  }

  void _sortByName() {
    setState(() {
      if (_sortOption == 'name') {
        _isReverse = !_isReverse;
      } else {
        _sortOption = 'name';
        _isReverse = false;
      }
      _applyFilters();
    });
    Fluttertoast.showToast(
        msg: _isReverse 
          ? (AppLocalizations.of(context)?.translate('sorted_by_name_reversed') ?? "Sorted by name, reversed") 
          : (AppLocalizations.of(context)?.translate('sorted_by_name') ?? "Sorted by name"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
        webPosition: 'center');
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(Icons.rss_feed,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 16),
                  Text(
                    AppLocalizations.of(context)?.translate('app_title') ?? 'FCM Box',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: Text(AppLocalizations.of(context)?.translate('all') ?? 'All'),
              selected: _filterLabels.contains('all'),
              onTap: () {
                setState(() {
                  _filterLabels = {};
                  _filterPriority = null;
                  _filterTime = null;
                  _filterTitle = null;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: Text(AppLocalizations.of(context)?.translate('starred') ?? 'Starred'),
              selected: _filterLabels.contains('starred'),
              onTap: () {
                setState(() {
                  _filterLabels = {'starred'};
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: Text(AppLocalizations.of(context)?.translate('archive') ?? 'Archive'),
              selected: _filterLabels.contains('archived'),
              onTap: () {
                setState(() {
                  _filterLabels = {'archived'};
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(AppLocalizations.of(context)?.translate('trash') ?? 'Trash'),
              selected: _filterLabels.contains('trashed'),
              onTap: () {
                setState(() {
                  _filterLabels = {'trashed'};
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ).then((_) => _loadSettings());
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(AppLocalizations.of(context)?.translate('about') ?? 'About'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SearchBar(
                elevation: WidgetStateProperty.all(0.0),
                backgroundColor: WidgetStateProperty.all(Colors.white),
                hintText: AppLocalizations.of(context)?.translate('search_hint') ?? "Search",
                hintStyle: WidgetStateProperty.all(const TextStyle(color: Colors.grey)),
                side: WidgetStateProperty.resolveWith<BorderSide>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.focused)) {
                      return BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      );
                    }
                    return BorderSide.none;
                  },
                ),
                leading: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black54),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                trailing: [
                  //const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      // print("点击头像");
                    },
                    customBorder: const CircleBorder(),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.purple,
                      child: Text("G", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                onTap: () {
                  // print("打开搜索页面");
                },
                onChanged: (value) {
                  // print("输入内容: $value");
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: _filterLabels.isEmpty
                          ? Text(AppLocalizations.of(context)?.translate('label') ?? 'Label')
                          : Text('${AppLocalizations.of(context)?.translate('label_prefix') ?? 'Label: '}${_filterLabels.map((l) => AppLocalizations.of(context)?.translate(l) ?? l).join(', ')}'),
                          
                      selected: _filterLabels.isNotEmpty,
                      backgroundColor: Colors.white,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      side: _filterLabels.isNotEmpty
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const BorderSide(color: Colors.grey, width: 0.5),
                      onSelected: (bool value) async {
                        final Set<String>? selected = await _showMultiSelectionSheet(
                          context,
                          AppLocalizations.of(context)?.translate('select_label') ?? 'Select Label',
                          ['starred', 'trashed', 'archived'],
                          Set.from(_filterLabels),
                        );
                        if (selected != null) {
                          setState(() {
                            _filterLabels = selected;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(_filterPriority == null 
                        ? (AppLocalizations.of(context)?.translate('priority') ?? 'Priority') 
                        : '${AppLocalizations.of(context)?.translate('priority_prefix') ?? 'Priority: '}${AppLocalizations.of(context)?.translate(_filterPriority!) ?? _filterPriority}'),
                      selected: _filterPriority != null,
                      backgroundColor: Colors.white,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      side: _filterPriority != null
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const BorderSide(color: Colors.grey, width: 0.5),
                      onSelected: (bool value) async {
                        if (!value) {
                          setState(() {
                            _filterPriority = null;
                            _applyFilters();
                          });
                          return;
                        }
                        final String? selected = await _showSelectionSheet(
                          context,
                          AppLocalizations.of(context)?.translate('select_priority') ?? 'Select Priority',
                          ['high', 'normal', 'low'],
                        );
                        if (selected != null) {
                          setState(() {
                            _filterPriority = selected;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(_filterTime == null 
                        ? (AppLocalizations.of(context)?.translate('time') ?? 'Time') 
                        : '${AppLocalizations.of(context)?.translate('time_prefix') ?? 'Time: '}${AppLocalizations.of(context)?.translate(_filterTime!.replaceAll(' ', '_')) ?? _filterTime}'),
                      selected: _filterTime != null,
                      backgroundColor: Colors.white,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      side: _filterTime != null
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const BorderSide(color: Colors.grey, width: 0.5),
                      onSelected: (bool value) async {
                        if (!value) {
                          setState(() {
                            _filterTime = null;
                            _applyFilters();
                          });
                          return;
                        }
                        final String? selected = await _showSelectionSheet(
                          context,
                          AppLocalizations.of(context)?.translate('select_time') ?? 'Select Time',
                          ['1 week', '1 month', '3 months'],
                        );
                        if (selected != null) {
                          setState(() {
                            _filterTime = selected;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(_filterTitle == null 
                        ? (AppLocalizations.of(context)?.translate('title') ?? 'Title') 
                        : '${AppLocalizations.of(context)?.translate('title_prefix') ?? 'Title: '}$_filterTitle'),
                      selected: _filterTitle != null,
                      backgroundColor: Colors.white,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      side: _filterTitle != null
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const BorderSide(color: Colors.grey, width: 0.5),
                      onSelected: (bool value) async {
                        if (!value) {
                          setState(() {
                            _filterTitle = null;
                            _applyFilters();
                          });
                          return;
                        }
                        final titles = _notes.map((n) => n.notification.title).toSet().toList();
                        final String? selected = await _showSelectionSheet(
                          context,
                          AppLocalizations.of(context)?.translate('select_title') ?? 'Select Title',
                          titles,
                        );
                        if (selected != null) {
                          setState(() {
                            _filterTitle = selected;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _sortOption == 'time'
                      ? (_isReverse ? "Sorted by time, reversed" : "Sorted by time")
                      : (_isReverse ? "Sorted by name, reversed" : "Sorted by name"),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredNotes.length,
                itemBuilder: (context, index) {
                  final note = _filteredNotes[index];
                  return Dismissible(
                    key: Key(note.data['note_id'] ?? note.notification.title),
                    background: Container(
                      color: _leftSwipeAction == 'archive' ? Colors.green : Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Icon(
                        _leftSwipeAction == 'archive' ? Icons.archive : Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    secondaryBackground: Container(
                      color: _rightSwipeAction == 'archive' ? Colors.green : Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      child: Icon(
                        _rightSwipeAction == 'archive' ? Icons.archive : Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      String action = direction == DismissDirection.startToEnd
                          ? _leftSwipeAction
                          : _rightSwipeAction;

                      setState(() {
                        final index = _notes.indexOf(note);
                        if (index != -1) {
                          if (action == 'archive') {
                            _notes[index] = note.copyWith(archived: !note.archived);
                          } else {
                            _notes[index] = note.copyWith(trashed: !note.trashed);
                          }
                          _applyFilters();
                        }
                      });
                      
                      String message;
                      if (action == 'archive') {
                        message = note.archived 
                          ? (AppLocalizations.of(context)?.translate('unarchived_message') ?? 'Unarchived')
                          : (AppLocalizations.of(context)?.translate('archived_message') ?? 'Archived');
                      } else {
                        message = note.trashed
                          ? (AppLocalizations.of(context)?.translate('restored_message') ?? 'Restored')
                          : (AppLocalizations.of(context)?.translate('deleted_message') ?? 'Deleted');
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$message ${note.notification.title}'),
                          action: SnackBarAction(
                            label: AppLocalizations.of(context)?.translate('undo') ?? 'Undo',
                            textColor: Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                final index = _notes.indexWhere((n) =>
                                    n.data['note_id'] == note.data['note_id'] &&
                                    n.notification.title ==
                                        note.notification.title &&
                                    n.time == note.time);
                                if (index != -1) {
                                  if (action == 'archive') {
                                    _notes[index] = _notes[index]
                                        .copyWith(archived: !_notes[index].archived);
                                  } else {
                                    _notes[index] = _notes[index]
                                        .copyWith(trashed: !_notes[index].trashed);
                                  }
                                  _applyFilters();
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                    child: _NoteCard(
                      note: note,
                      onTap: () {},
                      onToggleStar: () {
                        setState(() {
                          final index = _notes.indexOf(note);
                          if (index != -1) {
                            _notes[index] = note.copyWith(starred: !note.starred);
                            _applyFilters();
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.settings,
        activeIcon: Icons.close,
        spacing: 3,
        childPadding: const EdgeInsets.all(5),
        spaceBetweenChildren: 4,
        overlayColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[900]
            : Colors.grey[300],
        overlayOpacity: 0.5,
        children: [
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: _copyFcmToken,
              icon: const Icon(Icons.copy),
              label: Text(AppLocalizations.of(context)?.translate('copy_fcm_token') ?? 'Copy FCM Token'),
              key: const Key('copy_fcm_token'),
            ),
          ),
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: _sortByDate,
              icon: const Icon(Icons.sort),
              label: Text(AppLocalizations.of(context)?.translate('sort_by_time') ?? 'Sort by time'),
            ),
          ),
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: _sortByName,
              icon: const Icon(Icons.sort_by_alpha),
              label: Text(AppLocalizations.of(context)?.translate('sort_by_name') ?? 'Sort by name'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onToggleStar;
  final VoidCallback onTap;

  const _NoteCard({
    Key? key,
    required this.note,
    required this.onToggleStar,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = (_isHovered || _isPressed)
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE0E0E0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: widget.onTap,
        onHover: (val) {
          if (mounted) setState(() => _isHovered = val);
        },
        onTapDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 90),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.note.notification.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.note.notification.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      DateTime.fromMillisecondsSinceEpoch(widget.note.time * 1000)
                          .toString()
                          .split(' ')[0]
                          .replaceAll('-', '/'),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      widget.note.starred ? Icons.star : Icons.star_border,
                      color: widget.note.starred ? Colors.amber : Colors.grey,
                    ),
                    onPressed: widget.onToggleStar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
