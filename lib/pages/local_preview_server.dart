import 'dart:io';
import 'dart:typed_data';

class LocalPreviewServer {
  static final LocalPreviewServer instance = LocalPreviewServer._internal();
  HttpServer? _server;
  Uint8List? _currentBytes;
  String _currentMimeType = 'text/plain';

  LocalPreviewServer._internal();

  Future<void> start(Uint8List bytes, String mimeType) async {
    _currentBytes = bytes;
    _currentMimeType = mimeType;
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) {
      request.response.headers.set(HttpHeaders.contentTypeHeader, _currentMimeType);
      request.response.add(_currentBytes!);
      request.response.close();
    });
  }

  int get port => _server?.port ?? 0;
}
