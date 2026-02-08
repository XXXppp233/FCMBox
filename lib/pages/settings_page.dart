import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:fcm_box/services/google_drive_service.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class SettingsPage extends StatefulWidget {
  final Future<void> Function()? onSync;

  const SettingsPage({super.key, this.onSync});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // String _leftSwipeAction = 'archive'; // Removed
  // String _rightSwipeAction = 'delete'; // Removed
  bool _useMonet = false;
  int _selectedColorValue = Colors.blue.toARGB32();
  String _languageCode = 'en';
  String _themeMode = 'system';
  bool _usePureDark = false;
  // GoogleSignInAccount? _currentUser;

  final List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // _currentUser = GoogleDriveService().currentUser;
  }

  void _updateThemeSettings() {
    ThemeMode themeMode;
    switch (_themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }
    themeSettingsNotifier.value = ThemeSettings(
      _useMonet,
      _selectedColorValue,
      themeMode,
      _usePureDark,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // _leftSwipeAction = prefs.getString('left_swipe_action') ?? 'archive';
      // _rightSwipeAction = prefs.getString('right_swipe_action') ?? 'delete';
      _useMonet = prefs.getBool('use_monet') ?? false;
      _selectedColorValue =
          prefs.getInt('theme_color') ?? Colors.deepPurple.toARGB32();
      _languageCode = prefs.getString('language_code') ?? 'en';
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _usePureDark = prefs.getBool('use_pure_dark') ?? false;
    });
  }

  Future<void> _saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    setState(() {
      _languageCode = code;
    });
    localeSettingsNotifier.value = LocaleSettings(Locale(code));
  }

  // Swipe actions removed
  /*
  Future<void> _saveLeftSwipeAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('left_swipe_action', action);
    setState(() {
      _leftSwipeAction = action;
    });
  }

  Future<void> _saveRightSwipeAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('right_swipe_action', action);
    setState(() {
      _rightSwipeAction = action;
    });
  }
  */

  Future<void> _saveUseMonet(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_monet', value);
    setState(() {
      _useMonet = value;
    });
    _updateThemeSettings();
  }

  Future<void> _saveThemeColor(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', value);
    setState(() {
      _selectedColorValue = value;
    });
    _updateThemeSettings();
  }

  Future<void> _saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode);
    setState(() {
      _themeMode = mode;
    });
    _updateThemeSettings();
  }

  Future<void> _saveUsePureDark(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_pure_dark', value);
    setState(() {
      _usePureDark = value;
    });
    _updateThemeSettings();
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final color = _colors[index];
              return InkWell(
                onTap: () {
                  _saveThemeColor(color.toARGB32());
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  backgroundColor: color,
                  child: _selectedColorValue == color.toARGB32()
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('settings') ?? 'Settings',
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Theme',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text(
              AppLocalizations.of(context)?.translate('dark_mode') ??
                  'Dark Mode',
            ),
            subtitle: Text(
              _themeMode == 'system'
                  ? (AppLocalizations.of(
                          context,
                        )?.translate('system_default') ??
                        'System Default')
                  : _themeMode == 'dark'
                  ? (AppLocalizations.of(context)?.translate('on') ?? 'On')
                  : (AppLocalizations.of(context)?.translate('off') ?? 'Off'),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: Text(
                      AppLocalizations.of(context)?.translate('dark_mode') ??
                          'Dark Mode',
                    ),
                    children: [
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('system');
                        },
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('system_default') ??
                              'System Default',
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('dark');
                        },
                        child: Text(
                          AppLocalizations.of(context)?.translate('on') ?? 'On',
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('light');
                        },
                        child: Text(
                          AppLocalizations.of(context)?.translate('off') ??
                              'Off',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SwitchListTile(
            title: Text(
              AppLocalizations.of(context)?.translate('pure_dark_mode') ??
                  'Pure Dark Mode',
            ),
            subtitle: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('pure_dark_mode_subtitle') ??
                  'Use pure black background in dark mode',
            ),
            value: _usePureDark,
            onChanged: (bool value) {
              _saveUsePureDark(value);
            },
          ),
          SwitchListTile(
            title: Text(
              AppLocalizations.of(context)?.translate('use_monet') ??
                  'Use Android Monet',
            ),
            subtitle: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('use_android_monet_subtitle') ??
                  'Use dynamic colors from your wallpaper',
            ),
            value: _useMonet,
            onChanged: (bool value) {
              _saveUseMonet(value);
            },
          ),
          ListTile(
            title: Text(
              AppLocalizations.of(context)?.translate('theme_colors') ??
                  'Theme Colors',
            ),
            subtitle: _useMonet
                ? Text(
                    AppLocalizations.of(
                          context,
                        )?.translate('theme_color_subtitle_disabled') ??
                        'Disabled when Monet is enabled',
                  )
                : null,
            enabled: !_useMonet,
            trailing: CircleAvatar(
              backgroundColor: _useMonet
                  ? Color(_selectedColorValue).withValues(alpha: 0.5)
                  : Color(_selectedColorValue),
              radius: 12,
            ),
            onTap: _useMonet
                ? null
                : () {
                    _showColorPicker(context);
                  },
          ),
          // Swipe actions removed
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Language',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(
              AppLocalizations.of(context)?.translate('language') ?? 'Language',
            ),
            trailing: DropdownButton<String>(
              value: _languageCode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _saveLanguage(newValue);
                }
              },
              items: [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'zh', child: Text('简体中文')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Permissions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('notification_permission') ??
                  'Notification Permission',
            ),
            subtitle: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('notification_permission_subtitle') ??
                  'Allow app to post notifications',
            ),
            onTap: () async {
              final status = await Permission.notification.status;
              if (status.isDenied) {
                await Permission.notification.request();
              } else if (status.isPermanentlyDenied) {
                openAppSettings();
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('permission_granted') ??
                            'Permission already granted',
                      ),
                    ),
                  );
                }
              }
            },
          ),

          /*
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)?.translate('sync') ?? 'Sync',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: Text(AppLocalizations.of(context)?.translate('google_drive') ?? 'Google Drive'),
            subtitle: Text(_currentUser != null 
              ? '${AppLocalizations.of(context)?.translate('connected_as') ?? 'Connected as'} ${_currentUser!.email}' 
              : (AppLocalizations.of(context)?.translate('not_connected') ?? 'Not connected')),
            trailing: _currentUser != null
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: _handleSignOut,
                  )
                : IconButton(
                    icon: const Icon(Icons.login),
                    onPressed: _handleSignIn,
                  ),
          ),
          if (_currentUser != null)
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(AppLocalizations.of(context)?.translate('sync_now') ?? 'Sync Now'),
              onTap: _handleSync,
            ),
          */
        ],
      ),
    );
  }
}
