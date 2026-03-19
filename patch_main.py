import re

with open('lib/main.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
in_my_home_page_state = False

for line in lines:
    if "class _MyHomePageState extends State<MyHomePage>" in line:
        in_my_home_page_state = True
    
    if line.startswith("import 'dart:io';"):
        new_lines.append("import 'dart:async';\n")
        new_lines.append("import 'package:connectivity_plus/connectivity_plus.dart';\n")
        
    if in_my_home_page_state:
        if "final Set<String> _newlyAddedIds = {};" in line:
            new_lines.append(line)
            new_lines.append("""
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
""")
            continue
        
        if "WidgetsBinding.instance.addObserver(this);" in line:
            new_lines.append(line)
            new_lines.append("""
    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
""")
            continue
            
        if "  void dispose() {" in line and "super.dispose();" in "".join(lines[lines.index(line):lines.index(line)+10]):
            # Verify we are still in MyHomePageState by checking if this dispose has _refreshController
            # Well, it's safer to just inject our methods right before this specific dispose
            new_lines.append("""
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
""")
            new_lines.append(line)
            in_my_home_page_state = False # End of my home page state processing
            continue

        if "Icon(" in line and "Icons.rss_feed" in "".join(lines[lines.index(line):lines.index(line)+3]):
             # Replace the rss_feed line directly below
             pass
        
        if "Icons.rss_feed," in line:
            new_lines.append("                        _getNetworkIcon(),\n")
            continue

        if "super.dispose();" in line and not in_my_home_page_state:
            # We already left in_my_home_page_state when we hit dispose. But we need to add the cancel to the dispose block of MyHomePageState.
            pass

    new_lines.append(line)

with open('lib/main.dart', 'w') as f:
    f.writelines(new_lines)
