import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fcm_box/models/note.dart';
import 'package:fcm_box/pages/settings_page.dart';
import 'package:fcm_box/pages/about_page.dart';
import 'package:fcm_box/pages/cloud_page.dart';
import 'package:fcm_box/pages/json_viewer_page.dart';
import 'package:fcm_box/pages/search_page.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:fcm_box/db/notes_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:animations/animations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data.isEmpty) {
    return;
  }

  await Firebase.initializeApp();

  // Extract data for new model
  final notification = message.notification;
  final service = notification?.title ?? 'Unknown Service';
  final overview = notification?.body ?? '';
  final image = notification?.android?.imageUrl ?? message.data['image'];

  final timestamp = DateTime.now().millisecondsSinceEpoch;

  final newNote = Note(
    timestamp: timestamp,
    data: message.data,
    service: service,
    overview: overview,
    image: image,
    id: message.messageId,
  );

  await DatabaseHelper.instance.create(newNote);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
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
  }

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
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _refreshController;
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  Set<String> _services = {};

  String? _selectedService;
  int _quantityFilter = 20; // Default x
  int? _timeFilterStart;
  int? _timeFilterEnd;

  File? _faviconFile;
  bool _isLoading = false;
  final Set<String> _newlyAddedIds = {};

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _searchFocusNode.canRequestFocus = false;
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotes();
      _loadFavicon();
    }
  }

  Future<void> _initApp() async {
    await Permission.notification.request();
    await _loadNotes();
    await _loadFavicon();
    _setupFCM();
  }

  Future<void> _loadFavicon() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/favicon.ico');
    if (await file.exists()) {
      setState(() {
        _faviconFile = file;
      });
    }
  }

  void _setupFCM() {
    if (Firebase.apps.isEmpty) return;

    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
      _addNoteFromMessage(message);
      _refreshFromBackend(quantity: 1, deleteOld: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final note = _addNoteFromMessage(message);
      // Opens app via bubble -> Update based on current Quantity settings
      if (note != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => JsonViewerPage(note: note)),
        );
        _refreshFromBackend(quantity: _quantityFilter, deleteOld: false);
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && mounted) {
        final note = _addNoteFromMessage(message);
        if (note != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => JsonViewerPage(note: note)),
          );
          _refreshFromBackend(quantity: _quantityFilter, deleteOld: false);
        }
      }
    });
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final prefs = await SharedPreferences.getInstance();
    final String backendUrl = prefs.getString('backend_url') ?? '';

    if (backendUrl.isEmpty) return;

    final String authKey = prefs.getString('backend_auth') ?? '';
    final String ipAddress = prefs.getString('backend_ip') ?? '';
    final bool useHttps = prefs.getBool('backend_https') ?? true;

    // Strip protocol if present in stored URL
    String cleanUrl = backendUrl.replaceAll(RegExp(r'^https?://'), '');
    final uri = Uri.parse(useHttps ? 'https://$cleanUrl' : 'http://$cleanUrl');
    Uri targetUri = uri;
    Map<String, String> headers = {};

    if (authKey.isNotEmpty) {
      headers['Authorization'] = authKey;
    }

    if (ipAddress.isNotEmpty) {
      targetUri = uri.replace(host: ipAddress);
      headers['Host'] = cleanUrl;
    }

    try {
      String deviceName = "Unknown Device";
      if (Platform.isAndroid) {
        try {
          AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
          deviceName = androidInfo.model;
        } catch (_) {}
      }

      final body = json.encode({"device": deviceName, "token": newToken});

      await http.put(
        targetUri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      debugPrint('Token refresh sync failed: $e');
    }
  }

  Note? _addNoteFromMessage(RemoteMessage message) {
    if (message.data.isEmpty) return null;

    // Deduplication check
    if (_notes.any((n) => n.id == message.messageId)) return null;

    final notification = message.notification;
    final service = notification?.title ?? 'Unknown Service';
    final overview = notification?.body ?? '';
    final image = notification?.android?.imageUrl ?? message.data['image'];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final newNote = Note(
      timestamp: timestamp,
      data: message.data,
      service: service,
      overview: overview,
      image: image,
      id: message.messageId,
    );

    // Save to DB asynchronously
    DatabaseHelper.instance.create(newNote).then((_) {
      // Success
    });

    setState(() {
      _newlyAddedIds.add(newNote.id);
      _notes.insert(0, newNote);
      _updateServices();
      _applyFilters();
    });

    return newNote;
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await DatabaseHelper.instance.readAllNotes();
      setState(() {
        _notes = notes;
        _updateServices();
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading notes from DB: $e');
    }
  }

  void _updateServices() {
    _services = _notes.map((n) => n.service).toSet();
  }

  void _applyFilters() {
    setState(() {
      _filteredNotes = _notes.where((note) {
        if (_selectedService != null && note.service != _selectedService) {
          return false;
        }
        if (_timeFilterStart != null && note.timestamp < _timeFilterStart!) {
          return false;
        }
        if (_timeFilterEnd != null && note.timestamp > _timeFilterEnd!) {
          return false;
        }
        return true;
      }).toList();

      _filteredNotes.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (_filteredNotes.length > _quantityFilter) {
        _filteredNotes = _filteredNotes.sublist(0, _quantityFilter);
      }
    });
  }

  Future<void> _refreshFromBackend({int? quantity, bool? deleteOld}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    _refreshController.repeat();

    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('backend_url');
      final auth = prefs.getString('backend_auth');
      final useHttps = prefs.getBool('backend_https') ?? true;
      final ip = prefs.getString('backend_ip');
      final deleteOldSetting =
          deleteOld ?? (prefs.getBool('delete_old_data') ?? false);
      final quantityToFetch = quantity ?? _quantityFilter;

      if (url == null || url.isEmpty) {
        if (!mounted) return;
        Fluttertoast.showToast(
          msg:
              AppLocalizations.of(
                context,
              )?.translate('backend_not_configured') ??
              'Backend not configured',
        );
        return;
      }

      String cleanUrl = url.replaceAll(RegExp(r'^https?://'), '');
      final uri = Uri.parse((useHttps ? 'https://' : 'http://') + cleanUrl);
      Uri targetUri = uri;
      Map<String, String> headers = {'Content-Type': 'application/json'};
      if (auth != null && auth.isNotEmpty) headers['Authorization'] = auth;
      if (ip != null && ip.isNotEmpty) {
        targetUri = uri.replace(host: ip);
        headers['Host'] = cleanUrl;
      }

      final body = json.encode({
        "action": "get",
        "quantity": quantityToFetch,
        "service": _selectedService, // current or null
      });

      final response = await http.post(targetUri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final List<Note> newNotes = responseData
            .map((item) => Note.fromJson(item))
            .toList();

        if (deleteOldSetting) {
          if (_selectedService != null) {
            await DatabaseHelper.instance.deleteByService(_selectedService!);
            setState(() {
              _notes.removeWhere((n) => n.service == _selectedService);
            });
          } else {
            await DatabaseHelper.instance.deleteAll();
            setState(() {
              _notes = [];
            });
          }
        }

        final existingIds = _notes.map((n) => n.timestamp).toSet();
        final List<Note> notesToInsert = [];

        for (var n in newNotes) {
          if (!existingIds.contains(n.timestamp)) {
            notesToInsert.add(n);
            existingIds.add(n.timestamp);
          }
        }

        if (notesToInsert.isNotEmpty) {
          await DatabaseHelper.instance.insertBatch(notesToInsert);
          setState(() {
            _notes.insertAll(0, notesToInsert);
            // Sort again just in case, though insertAll(0) puts them at top implies they are newer if list was sorted
            // We must sort here after updating _notes
            _notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          });
        }

        if (deleteOldSetting) {
          // Already handled async above
        }

        // Final UI refresh
        setState(() {
          _updateServices();
          _applyFilters();
        });

        if (quantity == null) {
          if (!mounted) return;
          Fluttertoast.showToast(
            msg:
                '${AppLocalizations.of(context)?.translate('updated') ?? 'Updated'} ${newNotes.length} ${AppLocalizations.of(context)?.translate('items') ?? 'items'}',
          );
        }
      } else {
        Fluttertoast.showToast(msg: 'Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Refresh failed: $e');
      if (quantity == null) {
        if (mounted) {
          Fluttertoast.showToast(
            msg:
                '${AppLocalizations.of(context)?.translate('refresh_failed') ?? 'Refresh failed'}: $e',
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
      _refreshController.stop();
      _refreshController.reset();
    }
  }

  void _showQuantityPicker() async {
    double sliderValue = _quantityFilter.toDouble();
    if (sliderValue > 200) sliderValue = 200;

    await showDialog<int?>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                AppLocalizations.of(context)?.translate('select_quantity') ??
                    'Select Quantity',
              ),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Buttons + Current Value
                  SizedBox(
                    width: 88,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...[10, 20, 50, 100].map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: SizedBox(
                              height: 44,
                              width: 88,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    sliderValue = e.toDouble();
                                    _quantityFilter = e;
                                    _applyFilters();
                                  });
                                },
                                child: Text(
                                  '$e',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The 5th button: Current Slider Value
                        SizedBox(
                          height: 44,
                          width: 88,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            onPressed: null, // "Display only" but matched style
                            child: Text(
                              '${sliderValue.toInt()}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right: Vertical Custom Volume Bar
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      final renderBox =
                          context.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        // Height check
                      }
                    },
                    child: SizedBox(
                      height: 268, // (44 * 5) + (12 * 4) = 220 + 48 = 268
                      width: 88,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onVerticalDragUpdate: (details) {
                              double newY =
                                  constraints.maxHeight -
                                  details.localPosition.dy;
                              double newVal =
                                  (newY / constraints.maxHeight) * 200;
                              if (newVal < 0) newVal = 0;
                              if (newVal > 200) newVal = 200;

                              if (newVal.toInt() != _quantityFilter) {
                                HapticFeedback.selectionClick();
                              }

                              setState(() {
                                sliderValue = newVal;
                                _quantityFilter = newVal.toInt();
                                _applyFilters();
                              });
                            },
                            onTapUp: (details) {
                              double newY =
                                  constraints.maxHeight -
                                  details.localPosition.dy;
                              double newVal =
                                  (newY / constraints.maxHeight) * 200;
                              if (newVal < 0) newVal = 0;
                              if (newVal > 200) newVal = 200;

                              if (newVal.toInt() != _quantityFilter) {
                                HapticFeedback.selectionClick();
                              }

                              setState(() {
                                sliderValue = newVal;
                                _quantityFilter = newVal.toInt();
                                _applyFilters();
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Fill
                                  Container(
                                    height:
                                        (sliderValue / 200) *
                                        constraints.maxHeight,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        15,
                                      ), // Slightly less than border
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  void _showTimePicker() async {
    final DateTime? pickedRangeStart = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date',
    );
    if (pickedRangeStart != null) {
      setState(() {
        _timeFilterStart = pickedRangeStart.millisecondsSinceEpoch;
        _timeFilterEnd = null;
        _applyFilters();
      });
    } else {
      setState(() {
        _timeFilterStart = null;
        _timeFilterEnd = null;
        _applyFilters();
      });
    }
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.rss_feed,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'FCM Box',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: Text(
                AppLocalizations.of(context)?.translate('cloud') ?? 'Cloud',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CloudPage()),
                ).then((_) => _loadFavicon());
              },
            ),
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
                    builder: (context) => SettingsPage(onSync: () async {}),
                  ),
                ).then((_) {});
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: Text(
                AppLocalizations.of(context)?.translate('all') ?? 'All',
              ),
              selected: _selectedService == null,
              onTap: () {
                setState(() {
                  _selectedService = null;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            if (_services.isNotEmpty)
              ..._services.map(
                (s) => ListTile(
                  title: Text(s),
                  contentPadding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                  ), // Align to left edge (standard padding)
                  selected: _selectedService == s,
                  onTap: () {
                    setState(() {
                      _selectedService = s;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OpenContainer(
                      transitionType: ContainerTransitionType.fade,
                      openBuilder: (context, _) => const SearchPage(),
                      closedBuilder: (context, openContainer) => InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                          if (result != null &&
                              result is Map &&
                              result['type'] == 'service') {
                            setState(() {
                              _selectedService = result['value'];
                              _applyFilters();
                            });
                          }
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[900]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('search_hint') ??
                                    "Search",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      closedColor: Colors.transparent,
                      closedElevation: 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CloudPage(),
                        ),
                      ).then((_) => _loadFavicon());
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      backgroundImage: _faviconFile != null
                          ? FileImage(_faviconFile!)
                          : null,
                      child: _faviconFile == null
                          ? const Icon(Icons.cloud_off)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  if (_selectedService != null)
                    InputChip(
                      selected: true,
                      showCheckmark: false,
                      label: Text(_selectedService!),
                      onDeleted: () {
                        setState(() {
                          _selectedService = null;
                          _applyFilters();
                        });
                      },
                    )
                  else
                    ActionChip(
                      label: Text(
                        AppLocalizations.of(context)?.translate('all') ?? 'All',
                      ),
                      avatar: const Icon(Icons.filter_list, size: 18),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: Text('$_quantityFilter'),
                    onPressed: _showQuantityPicker,
                  ),
                  const SizedBox(width: 8),
                  InputChip(
                    selected: _timeFilterStart != null,
                    showCheckmark: false,
                    label: Text(
                      _timeFilterStart == null
                          ? 'Select Time'
                          : DateTime.fromMillisecondsSinceEpoch(
                              _timeFilterStart!,
                            ).toString().split(' ')[0],
                    ),
                    onPressed: _showTimePicker,
                    onDeleted: _timeFilterStart != null
                        ? () {
                            setState(() {
                              _timeFilterStart = null;
                              _applyFilters();
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = _filteredNotes[index];
                        final isNew = _newlyAddedIds.contains(note.id);

                        return _AnimatedEntryItem(
                          animate: isNew,
                          child: _NoteCardNew(
                            note: note,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JsonViewerPage(note: note),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () => _refreshFromBackend(),
        child: RotationTransition(
          turns: _refreshController,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class _AnimatedEntryItem extends StatefulWidget {
  final Widget child;
  final bool animate;

  const _AnimatedEntryItem({required this.child, required this.animate});

  @override
  State<_AnimatedEntryItem> createState() => _AnimatedEntryItemState();
}

class _AnimatedEntryItemState extends State<_AnimatedEntryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical,
      axisAlignment: -1.0,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}

class _NoteCardNew extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _NoteCardNew({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(note.timestamp);
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final timeString = isToday
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : date.toString().split(' ')[0];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.image != null && note.image!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      note.image!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notifications, color: Colors.grey[400]),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.overview,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            note.service,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeString,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
