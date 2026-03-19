import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Insert state vars
vars_code = """
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
"""
content = re.sub(r'(final Set<String> _newlyAddedIds = \{\};)', r'\1\n' + vars_code, content)

# Insert initState
init_code = """
    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
"""
content = re.sub(r'(WidgetsBinding\.instance\.addObserver\(this\);)', r'\1\n' + init_code, content)

# Insert methods
methods_code = """
  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (_) {
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus = result;
    });
  }
"""
content = re.sub(r'(void dispose\(\) \{)', methods_code + r'\n  @override\n  \1', content)

# Insert cancel in dispose
content = re.sub(r'(super\.dispose\(\);)', r'_connectivitySubscription.cancel();\n    \1', content)

with open('lib/main.dart', 'w') as f:
    f.write(content)
