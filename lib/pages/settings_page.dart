import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/localization.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:fcm_box/services/google_drive_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _leftSwipeAction = 'archive';
  String _rightSwipeAction = 'delete';
  bool _useMonet = false;
  int _selectedColorValue = Colors.deepPurple.value;
  String _languageCode = 'en';
  GoogleSignInAccount? _currentUser;

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
    _currentUser = GoogleDriveService().currentUser;
  }

  Future<void> _handleSignIn() async {
    try {
      final account = await GoogleDriveService().signIn();
      setState(() {
        _currentUser = account;
      });
    } catch (error) {
      debugPrint('Sign in failed: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await GoogleDriveService().signOut();
    setState(() {
      _currentUser = null;
    });
  }

  Future<void> _handleSync() async {
    if (_currentUser == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)?.translate('syncing') ?? 'Syncing...')),
    );
    
    await GoogleDriveService().syncData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('sync_complete') ?? 'Sync complete')),
      );
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _leftSwipeAction = prefs.getString('left_swipe_action') ?? 'archive';
      _rightSwipeAction = prefs.getString('right_swipe_action') ?? 'delete';
      _useMonet = prefs.getBool('use_monet') ?? false;
      _selectedColorValue =
          prefs.getInt('theme_color') ?? Colors.deepPurple.value;
      _languageCode = prefs.getString('language_code') ?? 'en';
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

  Future<void> _saveUseMonet(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_monet', value);
    setState(() {
      _useMonet = value;
    });
    themeSettingsNotifier.value = ThemeSettings(_useMonet, _selectedColorValue);
  }

  Future<void> _saveThemeColor(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', value);
    setState(() {
      _selectedColorValue = value;
    });
    themeSettingsNotifier.value = ThemeSettings(_useMonet, _selectedColorValue);
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
                  _saveThemeColor(color.value);
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  backgroundColor: color,
                  child: _selectedColorValue == color.value
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
        title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'Settings'),
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
          SwitchListTile(
            title: Text(AppLocalizations.of(context)?.translate('use_monet') ?? 'Use Android Monet'),
            subtitle: Text(AppLocalizations.of(context)?.translate('use_android_monet_subtitle') ?? 'Use dynamic colors from your wallpaper'),
            value: _useMonet,
            onChanged: (bool value) {
              _saveUseMonet(value);
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)?.translate('theme_colors') ?? 'Theme Colors'),
            subtitle: _useMonet
                ? Text(AppLocalizations.of(context)?.translate('theme_color_subtitle_disabled') ?? 'Disabled when Monet is enabled')
                : null,
            enabled: !_useMonet,
            trailing: CircleAvatar(
              backgroundColor: _useMonet
                  ? Color(_selectedColorValue).withOpacity(0.5)
                  : Color(_selectedColorValue),
              radius: 12,
            ),
            onTap: _useMonet
                ? null
                : () {
                    _showColorPicker(context);
                  },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Swipe Actions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swipe_left),
            title: Text(AppLocalizations.of(context)?.translate('left_swipe_action') ?? 'Left Swipe'),
            trailing: DropdownButton<String>(
              value: _leftSwipeAction,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _saveLeftSwipeAction(newValue);
                }
              },
              items: <String>['archive', 'delete']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value == 'archive' 
                    ? (AppLocalizations.of(context)?.translate('archive') ?? 'Archive') 
                    : (AppLocalizations.of(context)?.translate('delete') ?? 'Delete')),
                );
              }).toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swipe_right),
            title: Text(AppLocalizations.of(context)?.translate('right_swipe_action') ?? 'Right Swipe'),
            trailing: DropdownButton<String>(
              value: _rightSwipeAction,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _saveRightSwipeAction(newValue);
                }
              },
              items: <String>['archive', 'delete']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value == 'archive' 
                    ? (AppLocalizations.of(context)?.translate('archive') ?? 'Archive') 
                    : (AppLocalizations.of(context)?.translate('delete') ?? 'Delete')),
                );
              }).toList(),
            ),
          ),
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
            title: Text(AppLocalizations.of(context)?.translate('language') ?? 'Language'),
            trailing: DropdownButton<String>(
              value: _languageCode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _saveLanguage(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: 'zh',
                  child: Text('简体中文'),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }
}
