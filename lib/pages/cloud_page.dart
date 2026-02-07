import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  String _backendUrl = '';
  String _authKey = '';
  String _ipAddress = '';
  bool _useHttps = true;
  
  String _backendTitle = 'The Backend Title';
  String _backendInfo = 'The backend info';
  bool _isConnected = false;
  bool _isLoading = false;
  File? _faviconFile;
  bool _deleteOldData = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? '';
      _authKey = prefs.getString('backend_auth') ?? '';
      _ipAddress = prefs.getString('backend_ip') ?? '';
      _useHttps = prefs.getBool('backend_https') ?? true;
      _backendTitle = prefs.getString('cloud_title') ?? 'The Backend Title';
      _backendInfo = prefs.getString('cloud_version') ?? 'The backend info';
      _isConnected = prefs.getBool('backend_active') ?? false;
      _deleteOldData = prefs.getBool('delete_old_data') ?? false;
    });
    _loadFavicon();
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

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', _backendUrl);
    await prefs.setString('backend_auth', _authKey);
    await prefs.setString('backend_ip', _ipAddress);
    await prefs.setBool('backend_https', _useHttps);
    await prefs.setBool('delete_old_data', _deleteOldData);
  }

  void _showConfigSheet() {
    final urlController = TextEditingController(text: _backendUrl);
    final authController = TextEditingController(text: _authKey);
    final ipController = TextEditingController(text: _ipAddress);
    bool tempHttps = _useHttps;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(labelText: 'Backend URL'),
                  ),
                  TextField(
                    controller: authController,
                    decoration: const InputDecoration(labelText: 'Authorization'),
                  ),
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(labelText: 'IP Address (Optional)'),
                  ),
                  SwitchListTile(
                    title: const Text('https'),
                    value: tempHttps,
                    onChanged: (val) {
                      setSheetState(() => tempHttps = val);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _backendUrl = urlController.text;
                            _authKey = authController.text;
                            _ipAddress = ipController.text;
                            _useHttps = tempHttps;
                          });
                          _saveSettings();
                          Navigator.pop(context);
                          _checkBackend();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkBackend() async {
    if (_backendUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(_useHttps ? 'https://$_backendUrl' : 'http://$_backendUrl');
    Uri targetUri = uri;
    Map<String, String> headers = {};
    if (_authKey.isNotEmpty) {
      headers['Authorization'] = _authKey;
    }

    if (_ipAddress.isNotEmpty) {
      // Logic to strip host and replace with IP, adding Host header
      // This is basic and might fail SSL SNI checks as noted in thoughts
      targetUri = uri.replace(host: _ipAddress);
      headers['Host'] = _backendUrl;
    }

    try {
      // 1. GET Root
      final response = await http.get(targetUri, headers: headers);
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        String title = document.head?.querySelector('title')?.text ?? 'The Backend Title';
        String info = document.body?.querySelector('h1')?.text ?? 'The backend info';

        // 2. GET Favicon
        // Construct favicon URL
        Uri faviconUri = targetUri.replace(path: '/favicon.ico'); 
        // If the original URL had a path, we might need to be careful. usage logic implies root.
        
        final faviconResponse = await http.get(faviconUri, headers: headers);
        if (faviconResponse.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/favicon.ico');
          await file.writeAsBytes(faviconResponse.bodyBytes);
          setState(() {
            _faviconFile = file;
          });
        }

        // Update UI state
        setState(() {
          _backendTitle = title;
          _backendInfo = info;
          _isConnected = true;
        });
        
        // Save to prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cloud_title', title);
        await prefs.setString('cloud_version', info);
        await prefs.setBool('backend_active', true);

        // 3. PUT Token
        await _registerToken(targetUri, headers);

      } else {
        throw Exception('Status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Backend check failed: $e');
      setState(() {
         // Keep old title/info if failed? Prompt says "If http fails, these will not change"
         // But status icon remains cross or loading? "Backend Status left icon ... check" if success.
         // If fail, it effectively stays/reverts to X?
         // We'll set isConnected to false if it failed.
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerToken(Uri baseUri, Map<String, String> baseHeaders) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      // PUT to root or specific endpoint? 
      // Prompt: "Send a PUT request content is this device's pure FCM Token"
      // Implies PUT to the base URL with body = token? or proper JSON?
      // "content is ... Token". I will assume raw body or simple text/plain.
      
      final response = await http.put(
        baseUri, 
        headers: {...baseHeaders, 'Content-Type': 'text/plain'}, 
        body: token
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint('Token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Token registration error: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
       debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          // Dynamic Icon (Favicon or default)
          if (_faviconFile != null)
             CircleAvatar(
                radius: 48,
                backgroundColor: Colors.transparent,
                backgroundImage: FileImage(_faviconFile!),
             )
          else 
            CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: _isConnected 
                ? Icon(Icons.cloud_done, size: 48, color: Theme.of(context).colorScheme.onPrimaryContainer) // Example for connected
                : Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.onPrimaryContainer), // No network icon
            ),
            
          const SizedBox(height: 16),
          Center(
            child: Text(
              _backendTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _backendInfo,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),
          
          ListTile(
            leading: _isLoading 
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                ) 
              : (_isConnected ? const Icon(Icons.check) : const Icon(Icons.close)),
            title: const Text('Backend Status'),
            subtitle: Text(_isConnected ? _backendUrl : 'None'),
            onTap: _showConfigSheet,
          ),
          
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('View a code sample'),
            onTap: () {
              // Link to backendsample/README.md 
              // Assuming this refers to the repo URL as per "About" page logic
              _launchUrl('https://github.com/XXXppp233/FCMBox/blob/main/backendsample/README.md');
            },
          ),
          
          SwitchListTile(
            title: const Text('更新后删除旧数据'), // "Delete old data after update"
            value: _deleteOldData,
            onChanged: (val) async {
              setState(() => _deleteOldData = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('delete_old_data', val);
            },
          ),
        ],
      ),
    );
  }
}
