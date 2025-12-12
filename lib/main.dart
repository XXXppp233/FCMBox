import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:fcm_box/models/note.dart';
import 'package:fcm_box/pages/settings_page.dart';
import 'package:fcm_box/pages/about_page.dart';
import 'package:fcm_box/pages/json_viewer_page.dart';
import 'package:fcm_box/pages/title_selection_page.dart';
import 'package:fcm_box/pages/search_page.dart';
import 'package:fcm_box/pages/selection_pages.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:animations/animations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:fcm_box/services/google_drive_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final String? notesJson = prefs.getString('notes');
  List<dynamic> data = [];
  if (notesJson != null) {
    data = json.decode(notesJson);
  }

  final notification = message.notification;
  final title = notification?.title ?? 'No Title';
  final body = notification?.body ?? 'No Body';

  final dataMap = Map<String, dynamic>.from(message.data);
  if (message.messageId != null) {
    dataMap['_fcm_message_id'] = message.messageId;
  }

  // Use message.toMap() to preserve all original fields
  final newNoteJson = message.toMap();

  // Update/Inject our app-specific fields
  newNoteJson['data'] = dataMap;

  // Ensure notification field is a Map and has title/body (though toMap() should have it)
  // We merge to ensure we don't lose other notification fields but also ensure title/body are correct
  Map<String, dynamic> notificationMap = {};
  if (newNoteJson['notification'] is Map) {
    notificationMap = Map<String, dynamic>.from(newNoteJson['notification']);
  }
  notificationMap['title'] = title;
  notificationMap['body'] = body;
  newNoteJson['notification'] = notificationMap;

  newNoteJson['starred'] = false;
  newNoteJson['trashed'] = 0;
  newNoteJson['archived'] = false;
  newNoteJson['time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  newNoteJson['priority'] = message.data['priority'] ?? 'normal';

  data.insert(0, newNoteJson);
  await prefs.setString('notes', json.encode(data));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    if (kIsWeb) {
      debugPrint(
        "Web requires FirebaseOptions. Ensure you have configured it.",
      );
    }
  }

  // await GoogleDriveService().init();

  final prefs = await SharedPreferences.getInstance();
  final useMonet = prefs.getBool('use_monet') ?? false;
  final colorValue = prefs.getInt('theme_color') ?? Colors.blue.toARGB32();

  final themeModeString = prefs.getString('theme_mode') ?? 'system';
  ThemeMode themeMode;
  switch (themeModeString) {
    case 'light':
      themeMode = ThemeMode.light;
      break;
    case 'dark':
      themeMode = ThemeMode.dark;
      break;
    default:
      themeMode = ThemeMode.system;
  }
  final usePureDark = prefs.getBool('use_pure_dark') ?? false;

  themeSettingsNotifier.value = ThemeSettings(
    useMonet,
    colorValue,
    themeMode,
    usePureDark,
  );

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

                if (settings.useMonet &&
                    lightDynamic != null &&
                    darkDynamic != null) {
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
                  supportedLocales: const [Locale('en', ''), Locale('zh', '')],
                  themeMode: settings.themeMode,
                  theme: ThemeData(
                    colorScheme: lightScheme,
                    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                    useMaterial3: true,
                  ),
                  darkTheme: ThemeData(
                    colorScheme: settings.usePureDark
                        ? darkScheme.copyWith(surface: Colors.black)
                        : darkScheme,
                    scaffoldBackgroundColor: settings.usePureDark
                        ? Colors.black
                        : null,
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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();
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
  final ValueNotifier<bool> _isDialOpen = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.canRequestFocus = false;
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotes();
    }
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    await _loadSettings();
    await _loadNotes();
    _setupFCM();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  void _setupFCM() {
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase not initialized, skipping FCM setup.');
      return;
    }

    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }

      _addNoteFromMessage(message);
    });

    // Background -> Open App
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _addNoteFromMessage(message);
    });

    // Terminated -> Open App
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('App launched from notification');
        _addNoteFromMessage(message);
      }
    });
  }

  void _addNoteFromMessage(RemoteMessage message) {
    final messageId = message.messageId;
    if (messageId != null) {
      final exists = _notes.any((n) => n.data['_fcm_message_id'] == messageId);
      if (exists) return;
    }

    final notification = message.notification;
    final title = notification?.title ?? 'No Title';
    final body = notification?.body ?? 'No Body';

    final dataMap = Map<String, dynamic>.from(message.data);
    if (messageId != null) {
      dataMap['_fcm_message_id'] = messageId;
    }

    // Use message.toMap() to preserve all original fields
    final rawMap = message.toMap();

    // Update rawMap with our app-specific fields
    rawMap['starred'] = false;
    rawMap['trashed'] = 0;
    rawMap['archived'] = false;
    rawMap['time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    rawMap['priority'] = message.data['priority'] ?? 'normal';
    rawMap['data'] = dataMap;

    // Merge notification fields
    Map<String, dynamic> notificationMap = {};
    if (rawMap['notification'] is Map) {
      notificationMap = Map<String, dynamic>.from(rawMap['notification']);
    }
    notificationMap['title'] = title;
    notificationMap['body'] = body;
    rawMap['notification'] = notificationMap;

    final newNote = Note(
      notification: NotificationInfo(title: title, body: body),
      data: dataMap,
      starred: false,
      trashed: 0,
      archived: false,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      priority: message.data['priority'] ?? 'normal',
      rawJson: rawMap,
    );

    setState(() {
      _notes.insert(0, newNote);
      _applyFilters();
    });
    _saveNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("New Message: $title"),
          backgroundColor: Colors.green,
        ),
      );
    }
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final String? notesJson = prefs.getString('notes');
      if (notesJson != null) {
        final List<dynamic> data = json.decode(notesJson);
        setState(() {
          _notes = data.map((json) => Note.fromJson(json)).toList();

          // Cleanup old trashed notes
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final oneMonth = 30 * 24 * 60 * 60;
          _notes.removeWhere(
            (n) => n.trashed > 0 && (now - n.trashed) > oneMonth,
          );
          _saveNotes();

          _applyFilters();
        });
      } else {
        setState(() {
          _notes = [];
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String notesJson = json.encode(
      _notes.map((n) {
        final map = n.rawJson != null
            ? Map<String, dynamic>.from(n.rawJson!)
            : <String, dynamic>{};

        // Handle notification merging
        var notificationMap = <String, dynamic>{};
        if (map['notification'] != null && map['notification'] is Map) {
          notificationMap = Map<String, dynamic>.from(map['notification']);
        }
        notificationMap['title'] = n.notification.title;
        notificationMap['body'] = n.notification.body;
        map['notification'] = notificationMap;

        map['data'] = n.data;
        map['starred'] = n.starred;
        map['trashed'] = n.trashed;
        map['archived'] = n.archived;
        map['time'] = n.time;
        map['priority'] = n.priority;

        return map;
      }).toList(),
    );
    await prefs.setString('notes', notesJson);
  }

  void _applyFilters() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        // Label filter
        if (_filterLabels.isEmpty) {
          if (note.trashed > 0 || note.archived) return false;
        } else {
          bool match = false;
          if (_filterLabels.contains('starred') && note.starred) match = true;
          if (_filterLabels.contains('trashed') && note.trashed > 0) {
            match = true;
          }
          if (_filterLabels.contains('archived') && note.archived) match = true;
          if (!match) return false;
        }

        // Priority filter
        if (_filterPriority != null && note.priority != _filterPriority) {
          return false;
        }

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
        if (_filterTitle != null && note.notification.title != _filterTitle) {
          return false;
        }

        return true;
      }).toList();

      if (_sortOption == 'time') {
        _filteredNotes.sort(
          (a, b) =>
              _isReverse ? a.time.compareTo(b.time) : b.time.compareTo(a.time),
        );
      } else if (_sortOption == 'name') {
        _filteredNotes.sort(
          (a, b) => _isReverse
              ? b.notification.title.compareTo(a.notification.title)
              : a.notification.title.compareTo(b.notification.title),
        );
      }
    });
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('fcm_token_copied') ??
                  "FCM Token copied to clipboard",
            ),
          ),
        );
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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isReverse
              ? (AppLocalizations.of(
                      context,
                    )?.translate('sorted_by_time_reversed') ??
                    "Sorted by time, reversed")
              : (AppLocalizations.of(context)?.translate('sorted_by_time') ??
                    "Sorted by time"),
        ),
      ),
    );
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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isReverse
              ? (AppLocalizations.of(
                      context,
                    )?.translate('sorted_by_name_reversed') ??
                    "Sorted by name, reversed")
              : (AppLocalizations.of(context)?.translate('sorted_by_name') ??
                    "Sorted by name"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                  Icon(
                    Icons.rss_feed,
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppLocalizations.of(context)?.translate('app_title') ??
                        'FCM Box',
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
              title: Text(
                AppLocalizations.of(context)?.translate('all') ?? 'All',
              ),
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
              title: Text(
                AppLocalizations.of(context)?.translate('starred') ?? 'Starred',
              ),
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
              title: Text(
                AppLocalizations.of(context)?.translate('archive') ?? 'Archive',
              ),
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
              title: Text(
                AppLocalizations.of(context)?.translate('trash') ?? 'Trash',
              ),
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
              title: Text(
                AppLocalizations.of(context)?.translate('settings') ??
                    'Settings',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      onSync: () async {
                        /*
                        final jsonContent = json.encode(
                          _notes
                              .map(
                                (n) => {
                                  'notification': {
                                    'title': n.notification.title,
                                    'body': n.notification.body,
                                  },
                                  'data': n.data,
                                  'starred': n.starred,
                                  'trashed': n.trashed,
                                  'archived': n.archived,
                                  'time': n.time,
                                  'priority': n.priority,
                                },
                              )
                              .toList(),
                        );
                        await GoogleDriveService().syncData(jsonContent);
                        */
                      },
                    ),
                  ),
                ).then((_) => _loadSettings());
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(
                AppLocalizations.of(context)?.translate('about') ?? 'About',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OpenContainer(
                      transitionType: ContainerTransitionType.fade,
                      openBuilder: (BuildContext context, VoidCallback _) {
                        return const SearchPage();
                      },
                      tappable: false,
                      closedElevation: 0,
                      closedShape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                      ),
                      closedColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]!
                          : Colors.white,
                      closedBuilder:
                          (BuildContext context, VoidCallback openContainer) {
                            return SearchBar(
                              focusNode: _searchFocusNode,
                              elevation: WidgetStateProperty.all(0.0),
                              backgroundColor: WidgetStateProperty.all(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[900]
                                    : Colors.white,
                              ),
                              hintText:
                                  AppLocalizations.of(
                                    context,
                                  )?.translate('search_hint') ??
                                  "Search",
                              hintStyle: WidgetStateProperty.all(
                                const TextStyle(color: Colors.grey),
                              ),
                              side: WidgetStateProperty.resolveWith<BorderSide>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.focused)) {
                                    return BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2.0,
                                    );
                                  }
                                  return BorderSide.none;
                                },
                              ),
                              leading: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              onTap: openContainer,
                            );
                          },
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () {
                      // print("点击头像");
                    },
                    customBorder: const CircleBorder(),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.purple,
                      child: Text(
                        "G",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: _filterLabels.isEmpty
                          ? Text(
                              AppLocalizations.of(
                                    context,
                                  )?.translate('label') ??
                                  'Label',
                            )
                          : Text(
                              '${AppLocalizations.of(context)?.translate('label_prefix') ?? 'Label: '}${_filterLabels.map((l) => AppLocalizations.of(context)?.translate(l) ?? l).join(', ')}',
                            ),
                      selected: _filterLabels.isNotEmpty,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      side: _filterLabels.isNotEmpty
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const BorderSide(color: Colors.grey, width: 0.5),
                      onSelected: (bool value) async {
                        final selected =
                            await showModalBottomSheet<Set<String>>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => MultiSelectionPage(
                                title:
                                    AppLocalizations.of(
                                      context,
                                    )?.translate('select_label') ??
                                    'Select Label',
                                options: const [
                                  'starred',
                                  'trashed',
                                  'archived',
                                ],
                                selectedOptions: _filterLabels,
                              ),
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
                      label: Text(
                        _filterPriority == null
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('priority') ??
                                  'Priority')
                            : '${AppLocalizations.of(context)?.translate('priority_prefix') ?? 'Priority: '}${AppLocalizations.of(context)?.translate(_filterPriority!) ?? _filterPriority}',
                      ),
                      selected: _filterPriority != null,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
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
                        } else {
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => GenericSelectionPage(
                              title:
                                  AppLocalizations.of(
                                    context,
                                  )?.translate('select_priority') ??
                                  'Select Priority',
                              options: const ['high', 'normal', 'low'],
                              selectedOption: _filterPriority,
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              _filterPriority = selected;
                              _applyFilters();
                            });
                          }
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        _filterTime == null
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('time') ??
                                  'Time')
                            : '${AppLocalizations.of(context)?.translate('time_prefix') ?? 'Time: '}${AppLocalizations.of(context)?.translate(_filterTime!.replaceAll(' ', '_')) ?? _filterTime}',
                      ),
                      selected: _filterTime != null,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
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
                        } else {
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => GenericSelectionPage(
                              title:
                                  AppLocalizations.of(
                                    context,
                                  )?.translate('select_time') ??
                                  'Select Time',
                              options: const ['1 week', '1 month', '3 months'],
                              selectedOption: _filterTime,
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              _filterTime = selected;
                              _applyFilters();
                            });
                          }
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(
                        _filterTitle == null
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('title') ??
                                  'Title')
                            : '${AppLocalizations.of(context)?.translate('title_prefix') ?? 'Title: '}$_filterTitle',
                      ),
                      selected: _filterTitle != null,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
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
                        } else {
                          final titles = _notes
                              .map((n) => n.notification.title)
                              .toSet()
                              .toList();
                          final selected = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TitleSelectionPage(
                                allTitles: titles,
                                selectedTitle: _filterTitle,
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              _filterTitle = selected;
                              _applyFilters();
                            });
                          }
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
                      ? (_isReverse
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('sorted_by_time_reversed') ??
                                  "Sorted by time, reversed")
                            : (AppLocalizations.of(
                                    context,
                                  )?.translate('sorted_by_time') ??
                                  "Sorted by time"))
                      : (_isReverse
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('sorted_by_name_reversed') ??
                                  "Sorted by name, reversed")
                            : (AppLocalizations.of(
                                    context,
                                  )?.translate('sorted_by_name') ??
                                  "Sorted by name")),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.black,
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
                      color: _leftSwipeAction == 'archive'
                          ? Colors.green
                          : Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Icon(
                        _leftSwipeAction == 'archive'
                            ? Icons.archive
                            : Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    secondaryBackground: Container(
                      color: _rightSwipeAction == 'archive'
                          ? Colors.green
                          : Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      child: Icon(
                        _rightSwipeAction == 'archive'
                            ? Icons.archive
                            : Icons.delete,
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
                            _notes[index] = note.copyWith(
                              archived: !note.archived,
                            );
                          } else {
                            if (note.trashed > 0) {
                              _notes[index] = note.copyWith(trashed: 0);
                            } else {
                              _notes[index] = note.copyWith(
                                trashed:
                                    DateTime.now().millisecondsSinceEpoch ~/
                                    1000,
                                starred: false,
                                archived: false,
                              );
                            }
                          }
                          _applyFilters();
                          _saveNotes();
                        }
                      });

                      String message;
                      if (action == 'archive') {
                        message = note.archived
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('unarchived_message') ??
                                  'Unarchived')
                            : (AppLocalizations.of(
                                    context,
                                  )?.translate('archived_message') ??
                                  'Archived');
                      } else {
                        message = note.trashed > 0
                            ? (AppLocalizations.of(
                                    context,
                                  )?.translate('restored_message') ??
                                  'Restored')
                            : (AppLocalizations.of(
                                    context,
                                  )?.translate('moved_to_trash_message') ??
                                  'Moved to trash');
                      }

                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text('$message ${note.notification.title}'),
                          action: SnackBarAction(
                            label:
                                AppLocalizations.of(
                                  context,
                                )?.translate('undo') ??
                                'Undo',
                            textColor: Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                final index = _notes.indexWhere(
                                  (n) =>
                                      n.data['note_id'] ==
                                          note.data['note_id'] &&
                                      n.notification.title ==
                                          note.notification.title &&
                                      n.time == note.time,
                                );
                                if (index != -1) {
                                  if (action == 'archive') {
                                    _notes[index] = _notes[index].copyWith(
                                      archived: !_notes[index].archived,
                                    );
                                  } else {
                                    _notes[index] = note;
                                  }
                                  _applyFilters();
                                  _saveNotes();
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
                      onLongPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JsonViewerPage(note: note),
                          ),
                        );
                      },
                      onToggleStar: () {
                        setState(() {
                          final index = _notes.indexOf(note);
                          if (index != -1) {
                            _notes[index] = note.copyWith(
                              starred: !note.starred,
                            );
                            _applyFilters();
                            _saveNotes();
                          }
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _notes.remove(note);
                          _applyFilters();
                          _saveNotes();
                        });
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text(
                              '${AppLocalizations.of(context)?.translate('deleted_message') ?? 'Deleted'} ${note.notification.title}',
                            ),
                          ),
                        );
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
        openCloseDial: _isDialOpen,
        icon: Icons.settings,
        activeIcon: Icons.close,
        spacing: 3,
        childPadding: const EdgeInsets.all(5),
        spaceBetweenChildren: 4,
        overlayColor: Colors.grey[900],
        overlayOpacity: 0.5,
        children: [
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: () {
                _copyFcmToken();
                _isDialOpen.value = false;
              },
              icon: const Icon(Icons.copy),
              label: Text(
                AppLocalizations.of(context)?.translate('copy_fcm_token') ??
                    'Copy FCM Token',
              ),
              key: const Key('copy_fcm_token'),
            ),
          ),
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: _sortByDate,
              icon: const Icon(Icons.sort),
              label: Text(
                AppLocalizations.of(context)?.translate('sort_by_time') ??
                    'Sort by time',
              ),
            ),
          ),
          SpeedDialChild(
            labelWidget: FloatingActionButton.extended(
              onPressed: _sortByName,
              icon: const Icon(Icons.sort_by_alpha),
              label: Text(
                AppLocalizations.of(context)?.translate('sort_by_name') ??
                    'Sort by name',
              ),
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
  final VoidCallback? onDelete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NoteCard({
    required this.note,
    required this.onToggleStar,
    this.onDelete,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = (_isHovered || _isPressed)
        ? Theme.of(context).colorScheme.primary
        : (isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
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
                    DateTime.fromMillisecondsSinceEpoch(
                      widget.note.time * 1000,
                    ).toString().split(' ')[0].replaceAll('-', '/'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      widget.note.trashed > 0
                          ? Icons.delete_forever
                          : (widget.note.starred
                                ? Icons.star
                                : Icons.star_border),
                      color: widget.note.trashed > 0
                          ? Colors.red
                          : (widget.note.starred ? Colors.amber : Colors.grey),
                    ),
                    onPressed: widget.note.trashed > 0
                        ? widget.onDelete
                        : widget.onToggleStar,
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
