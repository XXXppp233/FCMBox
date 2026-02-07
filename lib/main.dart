import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.notification == null && message.data.isEmpty) {
    return;
  }

  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final String? notesJson = prefs.getString('notes');
  List<dynamic> data = [];
  if (notesJson != null) {
    try {
      data = json.decode(notesJson);
    } catch (_) {}
  }

  // Extract data for new model
  final notification = message.notification;
  final service = notification?.title ?? 'Unknown Service';
  final overview = notification?.body ?? '';
  final image = notification?.android?.imageUrl ?? message.data['image'];
  
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  // Create map matching Note.toJson()
  final newNoteMap = {
    'timestamp': timestamp,
    'data': message.data, 
    'service': service,
    'overview': overview,
    'image': image,
    '_id': message.messageId ?? '${timestamp}_$service',
  };

  data.insert(0, newNoteMap);
  await prefs.setString('notes', json.encode(data));
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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  Set<String> _services = {};
  
  String? _selectedService;
  int _quantityFilter = 20; // Default x
  int? _timeFilterStart;
  int? _timeFilterEnd; 

  File? _faviconFile;
  bool _isLoading = false;

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
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _addNoteFromMessage(message);
    });
    
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _addNoteFromMessage(message);
    });
  }

  void _addNoteFromMessage(RemoteMessage message) {
    if (message.notification == null && message.data.isEmpty) return;

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

    setState(() {
      _notes.insert(0, newNote);
      _updateServices();
      _applyFilters();
    });
    _saveNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String? notesJson = prefs.getString('notes');
    if (notesJson != null) {
      try {
        final List<dynamic> data = json.decode(notesJson);
        setState(() {
          _notes = data.map((json) {
            return Note.fromJson(json);
          }).toList();
          _updateServices();
          _applyFilters();
        });
      } catch (e) {
        debugPrint('Error loading notes: $e');
      }
    }
  }

  void _updateServices() {
    _services = _notes.map((n) => n.service).toSet();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String notesJson = json.encode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('notes', notesJson);
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

  Future<void> _refreshFromBackend() async {
    setState(() => _isLoading = true);
    try {
       final prefs = await SharedPreferences.getInstance();
       final url = prefs.getString('backend_url');
       final auth = prefs.getString('backend_auth');
       final useHttps = prefs.getBool('backend_https') ?? true;
       final ip = prefs.getString('backend_ip');
       final deleteOld = prefs.getBool('delete_old_data') ?? false;

       if (url == null || url.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend not configured')));
          return;
       }

       final uri = Uri.parse((useHttps ? 'https://' : 'http://') + url);
       Uri targetUri = uri;
       Map<String, String> headers = {'Content-Type': 'application/json'};
       if (auth != null && auth.isNotEmpty) headers['Authorization'] = auth;
       if (ip != null && ip.isNotEmpty) {
           targetUri = uri.replace(host: ip);
           headers['Host'] = url;
       }

       final body = json.encode({
         "action": "get",
         "quantity": _quantityFilter,
         "service": _selectedService // current or null
       });

       final response = await http.post(targetUri, headers: headers, body: body);

       if (response.statusCode == 200) {
          final List<dynamic> responseData = json.decode(response.body);
          final List<Note> newNotes = responseData.map((item) => Note.fromJson(item)).toList();
          
          setState(() {
            if (deleteOld) {
              _notes = newNotes;
            } else {
              final existingIds = _notes.map((n) => n.id).toSet();
              for (var n in newNotes) {
                if (!existingIds.contains(n.id)) {
                  _notes.insert(0, n);
                }
              }
            }
            _updateServices();
            _applyFilters();
          });
          _saveNotes();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${newNotes.length} items')));
       } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.statusCode}')));
       }
    } catch (e) {
       debugPrint('Refresh failed: $e');
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    } finally {
       setState(() => _isLoading = false);
    }
  }

  void _showQuantityPicker() async {
     final result = await showDialog<int>(
       context: context,
       builder: (context) {
         return AlertDialog(
           title: const Text('Select Quantity'),
           content: Wrap(
             spacing: 8,
             children: [10, 20, 50, 100].map((e) => ActionChip(
               label: Text('$e'),
               onPressed: () => Navigator.pop(context, e),
             )).toList(),
           ),
         );
       }
     );
     if (result != null) {
       setState(() {
         _quantityFilter = result;
         _applyFilters();
       });
     }
  }

  void _showTimePicker() async {
    final DateTime? pickedRangeStart = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date'
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
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Row(children: [
                      Icon(Icons.rss_feed, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 16),
                      Text('FCM Box', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 24)),
                   ]),
                   const SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Cloud'),
              onTap: () { 
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CloudPage())).then((_) => _loadFavicon());
              }, 
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage(onSync: () async {}))).then((_) {});
              },
            ),
             ListTile(
              leading: const Icon(Icons.info),
              title: Text(AppLocalizations.of(context)?.translate('about') ?? 'About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: Text(AppLocalizations.of(context)?.translate('all') ?? 'All'),
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
              ..._services.map((s) => ListTile(
                leading: const Icon(Icons.cloud_queue), 
                title: Text(s),
                selected: _selectedService == s,
                onTap: () {
                  setState(() {
                    _selectedService = s;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              )),
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
                    icon: Icon(Icons.menu, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OpenContainer(
                      transitionType: ContainerTransitionType.fade,
                      openBuilder: (context, _) => const SearchPage(),
                      closedBuilder: (context, openContainer) => InkWell(
                         onTap: () async {
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
                           if (result != null && result is Map && result['type'] == 'service') {
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
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                             borderRadius: BorderRadius.circular(24),
                           ),
                           child: Row(
                             children: [
                               const Icon(Icons.search, color: Colors.grey),
                               const SizedBox(width: 8),
                               Text(AppLocalizations.of(context)?.translate('search_hint') ?? "Search", style: const TextStyle(color: Colors.grey)),
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
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const CloudPage())).then((_) => _loadFavicon());
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      backgroundImage: _faviconFile != null ? FileImage(_faviconFile!) : null,
                      child: _faviconFile == null ? const Icon(Icons.cloud_off) : null,
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(children: [
                 if (_selectedService != null)
                 InputChip(
                   label: Text(_selectedService!),
                   onDeleted: () {
                     setState(() {
                       _selectedService = null;
                       _applyFilters();
                     });
                   },
                 ),
                 const SizedBox(width: 8),
                 ActionChip(
                   label: Text('Newest $_quantityFilter'),
                   onPressed: _showQuantityPicker,
                 ),
                 const SizedBox(width: 8),
                 InputChip(
                   label: Text(_timeFilterStart == null ? 'Select Time' : DateTime.fromMillisecondsSinceEpoch(_timeFilterStart!).toString().split(' ')[0]),
                   onPressed: _showTimePicker,
                   onDeleted: _timeFilterStart != null ? () {
                      setState(() {
                        _timeFilterStart = null;
                        _applyFilters();
                      });
                   } : null,
                 ),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                  itemCount: _filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = _filteredNotes[index];
                    return _NoteCardNew(note: note, 
                       onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => JsonViewerPage(note: note)));
                       },
                    );
                  },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshFromBackend,
        child: const Icon(Icons.refresh),
      ),
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
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final timeString = isToday 
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : date.toString().split(' ')[0];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
                        errorBuilder: (_,__,___) => Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
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
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
