import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../models/request_record.dart';
import '../db/notes_database.dart';
import '../l10n/app_localizations.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  List<RequestRecord> _requests = [];
  bool _isLoading = true;
  String _domainFilter = '';
  String _methodFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });
    final requests = await DatabaseHelper.instance.readAllRequests();
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  List<RequestRecord> get _filteredRequests {
    return _requests.where((r) {
      bool matchesDomain = _domainFilter.isEmpty || r.url.contains(_domainFilter);
      bool matchesMethod = _methodFilter.isEmpty || r.method == _methodFilter;
      return matchesDomain && matchesMethod;
    }).toList();
  }

  void _openComposer({bool useFcmTemplate = false, RequestRecord? template}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestComposerPage(
          useFcmTemplate: useFcmTemplate,
          template: template,
        ),
      ),
    );
    _loadRequests();
  }

  Set<String> get _domains {
    return _requests.map((r) {
      try {
        return Uri.parse(r.url).host;
      } catch (_) {
        return '';
      }
    }).where((s) => s.isNotEmpty).toSet();
  }

  Set<String> get _methods {
    return _requests.map((r) => r.method).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.request_api ?? 'Request API'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                InputChip(
                  label: Text(_domainFilter.isEmpty ? 'All Domains' : _domainFilter),
                  avatar: const Icon(Icons.public, size: 18),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Domain'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('All Domains'),
                                onTap: () {
                                  setState(() => _domainFilter = '');
                                  Navigator.pop(context);
                                },
                              ),
                              ..._domains.map((d) => ListTile(
                                title: Text(d),
                                onTap: () {
                                  setState(() => _domainFilter = d);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  onDeleted: _domainFilter.isEmpty ? null : () => setState(() => _domainFilter = ''),
                ),
                const SizedBox(width: 8),
                InputChip(
                  label: Text(_methodFilter.isEmpty ? 'All Methods' : _methodFilter),
                  avatar: const Icon(Icons.http, size: 18),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Method'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: const Text('All Methods'),
                                onTap: () {
                                  setState(() => _methodFilter = '');
                                  Navigator.pop(context);
                                },
                              ),
                              ..._methods.map((m) => ListTile(
                                title: Text(m),
                                onTap: () {
                                  setState(() => _methodFilter = m);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  onDeleted: _methodFilter.isEmpty ? null : () => setState(() => _methodFilter = ''),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRequests[index];
                      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getMethodColor(record.method),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  record.method,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  record.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(date.toString().split('.')[0]),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RequestDetailPage(record: record),
                              ),
                            );
                          },
                          onLongPress: () {
                            _openComposer(template: record);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 3,
        childPadding: const EdgeInsets.all(5),
        spaceBetweenChildren: 4,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.insert_drive_file),
            label: 'Blank Template',
            onTap: () => _openComposer(),
          ),
          SpeedDialChild(
            child: const Icon(Icons.cloud_upload),
            label: 'FCM Template',
            onTap: () => _openComposer(useFcmTemplate: true),
          ),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return Colors.blue;
      case 'POST': return Colors.green;
      case 'PUT': return Colors.orange;
      case 'DELETE': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class RequestComposerPage extends StatefulWidget {
  final bool useFcmTemplate;
  final RequestRecord? template;

  const RequestComposerPage({super.key, this.useFcmTemplate = false, this.template});

  @override
  State<RequestComposerPage> createState() => _RequestComposerPageState();
}

class _RequestComposerPageState extends State<RequestComposerPage> {
  String _method = 'GET';
  final _urlController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<Map<String, TextEditingController>> _headers = [];
  bool _isJsonMode = true;
  bool _isSending = false;

  static const List<String> _commonHeaders = [
    'Accept',
    'Accept-Encoding',
    'Accept-Language',
    'Authorization',
    'Cache-Control',
    'Connection',
    'Content-Length',
    'Content-Type',
    'Cookie',
    'Host',
    'Origin',
    'Referer',
    'User-Agent',
    'X-Requested-With',
  ];

  @override
  void initState() {
    super.initState();
    _initTemplate();
  }

  Future<void> _initTemplate() async {
    if (widget.template != null) {
      _method = widget.template!.method;
      _urlController.text = widget.template!.url;
      _bodyController.text = widget.template!.body;
      
      try {
        final Map<String, dynamic> headersMap = json.decode(widget.template!.headers);
        for (var entry in headersMap.entries) {
          _headers.add({
            'key': TextEditingController(text: entry.key),
            'value': TextEditingController(text: entry.value.toString()),
          });
        }
      } catch (_) {}
    } else if (widget.useFcmTemplate) {
      _method = 'POST';
      final prefs = await SharedPreferences.getInstance();
      String rawUrl = prefs.getString('backend_url') ?? '';
      String cleanUrl = rawUrl.replaceAll(RegExp(r'^https?://'), '');
      bool useHttps = prefs.getBool('backend_https') ?? true;
      _urlController.text = useHttps ? 'https://$cleanUrl' : 'http://$cleanUrl';

      String authKey = prefs.getString('backend_auth') ?? '';
      if (authKey.isNotEmpty) {
        _headers.add({
          'key': TextEditingController(text: 'Authorization'),
          'value': TextEditingController(text: authKey),
        });
      }
      
      _bodyController.text = '''{
  "action": "message",
  "service": "FCMBox Request",
  "overview": "This is a test request",
  "data": "This is a test data",
  "image": "https://apac-east1-i.wepayto.win/MD3/check_circle.png"
}''';
      _fillDefaultHeaders();
    } else {
      _fillDefaultHeaders();
    }

    _ensureEmptyHeaderRow();
    setState(() {});
  }

  void _fillDefaultHeaders() {
    _headers.add({
      'key': TextEditingController(text: 'User-Agent'),
      'value': TextEditingController(text: 'FCMBox/1.0'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Accept'),
      'value': TextEditingController(text: '*/*'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Accept-Encoding'),
      'value': TextEditingController(text: 'gzip, deflate, br'),
    });
    _headers.add({
      'key': TextEditingController(text: 'Connection'),
      'value': TextEditingController(text: 'keep-alive'),
    });
  }

  void _ensureEmptyHeaderRow() {
    bool shouldAdd = _headers.isEmpty || _headers.last['key']!.text.isNotEmpty || _headers.last['value']!.text.isNotEmpty;
    if (shouldAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _headers.add({
            'key': TextEditingController(),
            'value': TextEditingController(),
          });
        });
      });
    }
  }

  Map<String, String> _getHeadersMap() {
    Map<String, String> map = {};
    for (var h in _headers) {
      final k = h['key']!.text.trim();
      final v = h['value']!.text.trim();
      if (k.isNotEmpty) {
        map[k] = v;
      }
    }
    if (_isJsonMode && _method != 'GET' && _method != 'HEAD') {
      map['Content-Type'] = 'application/json';
    }
    return map;
  }

  Future<void> _sendRequest() async {
    setState(() => _isSending = true);
    try {
      final urlStr = _urlController.text.trim();
      if (urlStr.isEmpty) throw Exception('URL cannot be empty');
      
      final uri = Uri.parse(urlStr);
      final headersMap = _getHeadersMap();
      http.Response response;

      switch (_method) {
        case 'GET':
          response = await http.get(uri, headers: headersMap);
          break;
        case 'POST':
          response = await http.post(uri, headers: headersMap, body: _bodyController.text);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headersMap, body: _bodyController.text);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headersMap, body: _bodyController.text);
          break;
        default:
          throw Exception('Unsupported method');
      }

      final record = RequestRecord(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        url: urlStr,
        method: _method,
        headers: json.encode(headersMap),
        body: _bodyController.text,
      );
      
      await DatabaseHelper.instance.insertRequest(record);
      
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Response: ${response.statusCode}');
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Request'),
        actions: [
          if (_isSending)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            ))
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendRequest,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // URL Section
          const Text('URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Method Section
          const Text('Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _method,
                items: ['GET', 'POST', 'PUT', 'DELETE'].map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Headers Section
          const Text('Headers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _headers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _commonHeaders.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          _headers[index]['key']!.text = selection;
                          _ensureEmptyHeaderRow();
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          // Sync existing controller value when built
                          if (textEditingController.text != _headers[index]['key']!.text) {
                            textEditingController.text = _headers[index]['key']!.text;
                          }
                          textEditingController.addListener(() {
                            _headers[index]['key']!.text = textEditingController.text;
                            _ensureEmptyHeaderRow();
                          });
                          
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Key',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _headers[index]['value'],
                        decoration: const InputDecoration(
                          hintText: 'Value',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _ensureEmptyHeaderRow(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: index == _headers.length - 1 && _headers[index]['key']!.text.isEmpty && _headers[index]['value']!.text.isEmpty 
                        ? null 
                        : () {
                            setState(() {
                              _headers.removeAt(index);
                              _ensureEmptyHeaderRow();
                            });
                          },
                    )
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Body Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Body', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  const Text('RAW'),
                  Switch(
                    value: _isJsonMode,
                    onChanged: (v) => setState(() => _isJsonMode = v),
                  ),
                  const Text('JSON'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: 10,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Request Body',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 40), // Padding for scrolling
        ],
      ),
    );
  }
}

class RequestDetailPage extends StatelessWidget {
  final RequestRecord record;

  const RequestDetailPage({super.key, required this.record});

  Widget _buildHeadersPreview() {
    try {
      final Map<String, dynamic> headersMap = json.decode(record.headers);
      if (headersMap.isEmpty) {
        return const Text('(Empty)', style: TextStyle(color: Colors.grey));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: headersMap.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: SelectableText('${e.value}')),
              ],
            ),
          );
        }).toList(),
      );
    } catch (_) {
      return SelectableText(record.headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SelectableText(record.url, style: const TextStyle(fontSize: 16)),
          const Divider(height: 32),
          
          const Text('Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Text(record.method, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
          ),
          const Divider(height: 32),
          
          const Text('Headers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildHeadersPreview(),
          ),
          const Divider(height: 32),
          
          const Text('Body', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              record.body.isEmpty ? '(Empty)' : record.body,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
