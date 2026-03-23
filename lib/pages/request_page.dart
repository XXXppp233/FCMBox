import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/request_record.dart';
import '../db/notes_database.dart';
import '../l10n/app_localizations.dart';
import 'local_preview_server.dart';

const int _maxPreviewBytes = 1024 * 1024;

Future<bool> _isResponseTooLargeByHead({
  required Uri uri,
  required Map<String, String> headers,
}) async {
  try {
    final response = await http.head(uri, headers: headers);
    final lengthHeader = response.headers['content-length'];
    if (lengthHeader == null) return false;
    final length = int.tryParse(lengthHeader);
    if (length == null) return false;
    return length > _maxPreviewBytes;
  } catch (_) {
    return false;
  }
}

List<Uri> _buildHttpCandidates(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const [];
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return const [];
  if (parsed.hasScheme) return [parsed];
  final https = Uri.tryParse('https://$trimmed');
  final http = Uri.tryParse('http://$trimmed');
  final candidates = <Uri>[];
  if (https != null) candidates.add(https);
  if (http != null) candidates.add(http);
  return candidates;
}

bool _isHttpUri(Uri uri) {
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

Future<({Uri uri, http.StreamedResponse streamedResponse, bool skipPreview})>
    _sendWithFallback({
  required String urlInput,
  required String method,
  required Map<String, String> headers,
  required String body,
}) async {
  final candidates = _buildHttpCandidates(urlInput);
  if (candidates.isEmpty) {
    throw Exception('Invalid URL');
  }

  Object? lastError;
  for (final candidate in candidates) {
    if (!_isHttpUri(candidate)) {
      lastError = Exception('Invalid URL: missing host');
      continue;
    }
    final bool skipPreviewForLargeResponse =
        method != 'GET' &&
        await _isResponseTooLargeByHead(uri: candidate, headers: headers);
    final request = http.Request(method, candidate);
    request.headers.addAll(headers);
    if (method != 'GET' && method != 'HEAD') {
      request.body = body;
    }
    try {
      final streamedResponse = await request.send();
      return (
        uri: candidate,
        streamedResponse: streamedResponse,
        skipPreview: skipPreviewForLargeResponse,
      );
    } catch (e) {
      lastError = e;
    }
  }

  throw Exception('Request failed for https and http: $lastError');
}

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
  final _key = GlobalKey<ExpandableFabState>();

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
      bool matchesDomain =
          _domainFilter.isEmpty || r.url.contains(_domainFilter);
      bool matchesMethod = _methodFilter.isEmpty || r.method == _methodFilter;
      return matchesDomain && matchesMethod;
    }).toList();
  }

  void _openComposer({
    bool useFcmTemplate = false,
    RequestRecord? template,
  }) async {
    HapticFeedback.mediumImpact();
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

  void _deleteRequests() async {
    HapticFeedback.heavyImpact();
    await DatabaseHelper.instance.deleteAllRequests();
    _loadRequests();
  }

  Set<String> get _domains {
    return _requests
        .map((r) {
          try {
            return Uri.parse(r.url).host;
          } catch (_) {
            return '';
          }
        })
        .where((s) => s.isNotEmpty)
        .toSet();
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    _domainFilter.isEmpty ? 'All Domains' : _domainFilter,
                  ),
                  avatar: const Icon(Icons.public, size: 18),
                  selected: _domainFilter.isNotEmpty,
                  onSelected: (_) {
                    HapticFeedback.lightImpact();
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
                              ..._domains.map(
                                (d) => ListTile(
                                  title: Text(d),
                                  onTap: () {
                                    setState(() => _domainFilter = d);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    _methodFilter.isEmpty ? 'All Methods' : _methodFilter,
                  ),
                  avatar: const Icon(Icons.http, size: 18),
                  selected: _methodFilter.isNotEmpty,
                  onSelected: (_) {
                    HapticFeedback.lightImpact();
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
                              ..._methods.map(
                                (m) => ListTile(
                                  title: Text(m),
                                  onTap: () {
                                    setState(() => _methodFilter = m);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        record.timestamp,
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RequestDetailPage(record: record),
                              ),
                            );
                          },
                          onLongPress: () {
                            _openComposer(template: record);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  record.method,
                                  style: TextStyle(
                                    color: _getMethodColor(record.method),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date.toString().split('.')[0],
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: _key,
        type: ExpandableFabType.up,
        distance: 60,
        childrenAnimation: ExpandableFabAnimation.none,
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: const Icon(Icons.add),
          fabSize: ExpandableFabSize.regular,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: const Icon(Icons.close),
          fabSize: ExpandableFabSize.regular,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withValues(alpha: 0.5),
          blur: 0.5,
        ),
        children: [
          Row(
            children: [
              FloatingActionButton.extended(
                enableFeedback: true,
                heroTag: null,
                shape: const StadiumBorder(),
                onPressed: () {
                  final state = _key.currentState;
                  if (state != null) {
                    state.toggle();
                  }
                  _openComposer();
                },
                icon: const Icon(Icons.insert_drive_file_outlined),
                label: const Text('Blank Request'),
              ),
            ],
          ),
          Row(
            children: [
              FloatingActionButton.extended(
                enableFeedback: true,
                heroTag: null,
                shape: const StadiumBorder(),
                onPressed: () {
                  final state = _key.currentState;
                  if (state != null) {
                    state.toggle();
                  }
                  _openComposer(useFcmTemplate: true);
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('FCM Template'),
              ),
            ],
          ),
          Row(
            children: [
              FloatingActionButton.extended(
                enableFeedback: true,
                heroTag: null,
                shape: const StadiumBorder(),
                onPressed: () {
                  final state = _key.currentState;
                  if (state != null) {
                    state.toggle();
                  }
                  _deleteRequests();
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.orange;
      case 'PUT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class RequestComposerPage extends StatefulWidget {
  final bool useFcmTemplate;
  final RequestRecord? template;

  const RequestComposerPage({
    super.key,
    this.useFcmTemplate = false,
    this.template,
  });

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
        final Map<String, dynamic> headersMap = json.decode(
          widget.template!.headers,
        );
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
    bool shouldAdd =
        _headers.isEmpty ||
        _headers.last['key']!.text.isNotEmpty ||
        _headers.last['value']!.text.isNotEmpty;
    if (shouldAdd) {
      if (mounted) {
        setState(() {
          _headers.add({
            'key': TextEditingController(),
            'value': TextEditingController(),
          });
        });
      }
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
    HapticFeedback.vibrate();
    setState(() => _isSending = true);
    try {
      final urlStr = _urlController.text.trim();
      if (urlStr.isEmpty) throw Exception('URL cannot be empty');

      final headersMap = _getHeadersMap();
      
      final result = await _sendWithFallback(
        urlInput: urlStr,
        method: _method,
        headers: headersMap,
        body: _bodyController.text,
      );
      final uri = result.uri;
      final streamedResponse = result.streamedResponse;
      final skipPreviewForLargeResponse = result.skipPreview;

      final record = RequestRecord(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        url: uri.toString(),
        method: _method,
        headers: json.encode(headersMap),
        body: _bodyController.text,
      );
      await DatabaseHelper.instance.insertRequest(record);
      if (skipPreviewForLargeResponse) {
        streamedResponse.stream.listen((_) {}).cancel();
        Fluttertoast.showToast(msg: "返回体过大（>1MB），已跳过预览");
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
      if (_method == 'GET') {
        streamedResponse.stream.listen((_) {}).cancel(); 
        try {
          if (!await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: WebViewConfiguration(headers: headersMap)
          )) {
            Fluttertoast.showToast(msg: "Failed to open in browser");
          }
        } catch (e) {
          Fluttertoast.showToast(msg: "Error opening browser: $e");
        }
      } else {
        final response = await http.Response.fromStream(streamedResponse);
        try {
          final mimeType = response.headers['content-type'] ?? 'text/html';
          await LocalPreviewServer.instance.start(response.bodyBytes, mimeType);
          final localUrl = Uri.parse('http://localhost:${LocalPreviewServer.instance.port}');
          if (!await launchUrl(
            localUrl,
            mode: LaunchMode.inAppWebView,
          )) {
            Fluttertoast.showToast(msg: "Failed to launch WebView");
          }
        } catch (e) {
          Fluttertoast.showToast(msg: "Error launching WebView: $e");
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
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
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.send), onPressed: _sendRequest),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // URL Section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://api.example.com',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Method Section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DropdownMenu<String>(
              initialSelection: _method,
              label: const Text('Method'),
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSelected: (v) {
                if (v != null) setState(() => _method = v);
              },
              dropdownMenuEntries: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                  .map((m) {
                    return DropdownMenuEntry(value: m, label: m);
                  })
                  .toList(),
            ),
          ),

          // Headers Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Headers',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _headers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
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
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          _headers[index]['key']!.text = selection;
                          _ensureEmptyHeaderRow();
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (textEditingController.text !=
                                  _headers[index]['key']!.text) {
                                textEditingController.text =
                                    _headers[index]['key']!.text;
                              }

                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onChanged: (val) {
                                  _headers[index]['key']!.text = val;
                                  _ensureEmptyHeaderRow();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Key',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
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
                        decoration: InputDecoration(
                          hintText: 'Value',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => _ensureEmptyHeaderRow(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed:
                          index == _headers.length - 1 &&
                              _headers[index]['key']!.text.isEmpty &&
                              _headers[index]['value']!.text.isEmpty
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _headers.removeAt(index);
                                _ensureEmptyHeaderRow();
                              });
                            },
                    ),
                  ],
                ),
              );
            },
          ),

          // Body Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Body',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.raw_on)),
                    ButtonSegment(value: true, icon: Icon(Icons.data_object)),
                  ],
                  selected: {_isJsonMode},
                  onSelectionChanged: (set) => {
                    HapticFeedback.lightImpact(),
                    setState(() => _isJsonMode = set.first),
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _bodyController,
              maxLines: 12,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Request Payload',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
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

  Widget _buildUrlTable(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            border: TableBorder(
              verticalInside: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectableText(
                      record.method,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getMethodColor(record.method),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectableText(
                      record.url,
                      style: const TextStyle(overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeadersTable(BuildContext context) {
    Map<String, dynamic> headersMap = {};
    try {
      headersMap = json.decode(record.headers);
    } catch (_) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SelectableText(record.headers),
      );
    }

    if (headersMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text('(Empty)', style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              verticalInside: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: headersMap.entries.map((e) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectableText(
                      e.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectableText(
                      e.value.toString(),
                      style: const TextStyle(overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBodySection(BuildContext context) {
    if (record.body.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text('(Empty)', style: TextStyle(color: Colors.grey)),
      );
    }

    String prettyJson = record.body;
    bool isJson = false;
    try {
      final parsed = json.decode(record.body);
      prettyJson = const JsonEncoder.withIndent('  ').convert(parsed);
      isJson = true;
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isJson
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: HighlightView(
                  prettyJson,
                  language: 'json',
                  theme: Theme.of(context).brightness == Brightness.dark
                      ? atomOneDarkTheme
                      : atomOneLightTheme,
                  padding: const EdgeInsets.all(16.0),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  record.body,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.orange;
      case 'PUT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _resendRequestWithWebView(BuildContext context) async {
    HapticFeedback.vibrate();
    Fluttertoast.showToast(msg: "Sending request...");
    try {
      final headersMap = json.decode(record.headers) as Map<String, dynamic>;
      final Map<String, String> stringHeaders = headersMap.map((key, value) => MapEntry(key, value.toString()));
      final candidates = _buildHttpCandidates(record.url);
      if (candidates.isEmpty) {
        Fluttertoast.showToast(msg: "Invalid URL");
        return;
      }

      if (record.method == 'GET') {
        Object? lastError;
        for (final candidate in candidates) {
          if (!_isHttpUri(candidate)) continue;
          try {
            final config = WebViewConfiguration(headers: stringHeaders);
            if (await launchUrl(
              candidate,
              mode: LaunchMode.inAppWebView,
              webViewConfiguration: config,
            )) {
              return;
            }
          } catch (e) {
            lastError = e;
          }
        }
        Fluttertoast.showToast(msg: "Error opening browser: $lastError");
        return;
      }

      final result = await _sendWithFallback(
        urlInput: record.url,
        method: record.method,
        headers: stringHeaders,
        body: record.body,
      );
      final streamedResponse = result.streamedResponse;
      final skipPreviewForLargeResponse = result.skipPreview;
      if (skipPreviewForLargeResponse) {
        streamedResponse.stream.listen((_) {}).cancel();
        Fluttertoast.showToast(msg: "返回体过大（>1MB），已跳过预览");
        return;
      }
      final response = await http.Response.fromStream(streamedResponse);
      try {
        final mimeType = response.headers['content-type'] ?? 'text/html';
        await LocalPreviewServer.instance.start(response.bodyBytes, mimeType);
        final localUrl = Uri.parse('http://localhost:${LocalPreviewServer.instance.port}');
        if (!await launchUrl(
          localUrl,
          mode: LaunchMode.inAppWebView,
        )) {
          Fluttertoast.showToast(msg: "Failed to launch WebView");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Error launching WebView: $e");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _resendRequestWithWebView(context),
            tooltip: 'Resend & Open in WebView',
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Url',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildUrlTable(context),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Headers',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildHeadersTable(context),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Body',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildBodySection(context),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
