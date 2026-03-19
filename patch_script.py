import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# 1. Imports
content = re.sub(r"import 'dart:io';", "import 'dart:async';\nimport 'package:connectivity_plus/connectivity_plus.dart';\nimport 'dart:io';", content)

# 2. State variables
state_vars = """  final Set<String> _newlyAddedIds = {};

  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
"""
content = re.sub(r"  final Set<String> _newlyAddedIds = \{\};", state_vars, content)

# 3. initState
init_code = """    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
"""
content = re.sub(r"    WidgetsBinding\.instance\.addObserver\(this\);", init_code, content)

# 4. Methods and dispose cancel
methods = """
  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (_) {
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

  IconData _getNetworkIcon() {
    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      return Icons.wifi;
    } else if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      return Icons.signal_cellular_4_bar;
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      return Icons.settings_ethernet;
    } else if (_connectionStatus.contains(ConnectivityResult.none)) {
      return Icons.wifi_off;
    }
    return Icons.rss_feed;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();"""

# Need to replace ONLY the first occurrence of `  @override\n  void dispose() {`
content = content.replace("  @override\n  void dispose() {", methods, 1)

# 5. Icon change
content = re.sub(r"Icons\.rss_feed,", "_getNetworkIcon(),", content)

with open('lib/main.dart', 'w') as f:
    f.write(content)
