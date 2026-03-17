import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:fcm_box/localization.dart';

class FcmStatusPage extends StatefulWidget {
  const FcmStatusPage({super.key});

  @override
  State<FcmStatusPage> createState() => _FcmStatusPageState();
}

class _FcmStatusPageState extends State<FcmStatusPage> with WidgetsBindingObserver {
  final bool _isGoogleServiceEnabled = true; // Assume true for now
  bool _isVpnUsed = false;
  String _vpnName = '';
  
  bool _isConnected = false;
  String _host = 'Loading...';
  String _port = 'Unknown';
  String _fcmToken = 'Loading...';

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _fetchStatus();
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _fetchStatus();
    } else if (state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchStatus();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchStatus() async {
    // 1. Check VPN
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      bool hasVpn = false;
      String vpnInterface = '';
      for (var interface in interfaces) {
        if (interface.name.contains('tun') || 
            interface.name.contains('ppp') || 
            interface.name.contains('wg') || 
            interface.name.contains('tap')) {
          hasVpn = true;
          vpnInterface = interface.name;
          break;
        }
      }
      
      String vpnDisplayName = vpnInterface;
      if (hasVpn && Platform.isAndroid) {
         try {
           final result = await Process.run('dumpsys', ['connectivity']);
           if (result.exitCode == 0) {
             final output = result.stdout.toString();
             final uidMatch = RegExp(r'ownerUid:\s*(\d+)').firstMatch(output);
             if (uidMatch != null) {
                final uid = uidMatch.group(1);
                final pmResult = await Process.run('pm', ['list', 'packages', '--uid', uid!]);
                if (pmResult.exitCode == 0) {
                  final pmOutput = pmResult.stdout.toString();
                  final pkgMatch = RegExp(r'package:([^\s]+)\s+uid:').firstMatch(pmOutput);
                  if (pkgMatch != null) {
                     vpnDisplayName = pkgMatch.group(1)!;
                  }
                }
             }
           }
         } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isVpnUsed = hasVpn;
          _vpnName = vpnDisplayName.isNotEmpty ? vpnDisplayName : 'Unknown';
        });
      }
    } catch (_) {}

    // 2. Fetch Token
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (mounted) {
        setState(() {
          _fcmToken = token ?? 'Failed to get token';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fcmToken = 'Error: $e';
        });
      }
    }

    // Reset TCP status before parsing
    bool isConnected = false;
    String host = 'mtalk.google.com';
    String port = 'Unknown';
    String? foundIp;

    // 3. DNS Lookup (Base fallback)
    try {
      final results = await InternetAddress.lookup('mtalk.google.com');
      if (results.isNotEmpty && results[0].rawAddress.isNotEmpty) {
         host = 'mtalk.google.com/${results[0].address}';
      }
    } catch (_) {}
    
    if (Platform.isAndroid) {
      // Check IPv4 connections
      try {
        final file = File('/proc/net/tcp');
        if (file.existsSync()) {
          final lines = file.readAsLinesSync();
          for (var line in lines.skip(1)) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length > 3) {
              final remAddr = parts[2];
              final state = parts[3];
              if (state == '01') { // ESTABLISHED
                 final hostPort = remAddr.split(':');
                 if (hostPort.length == 2) {
                   final portHex = hostPort[1];
                   final portInt = int.parse(portHex, radix: 16);
                   if (portInt == 5228 || portInt == 5229 || portInt == 5230) {
                      final ipHex = hostPort[0];
                      final ipParts = <int>[];
                      for(int i = 0; i < ipHex.length; i += 2) {
                         ipParts.add(int.parse(ipHex.substring(i, i+2), radix: 16));
                      }
                      if (ipParts.length == 4) {
                        foundIp = '${ipParts[3]}.${ipParts[2]}.${ipParts[1]}.${ipParts[0]}';
                        port = portInt.toString();
                        isConnected = true;
                        break;
                      }
                   }
                 }
              }
            }
          }
        }
      } catch (_) {}

      // Check IPv6 connections if not found
      if (!isConnected) {
        try {
          final file = File('/proc/net/tcp6');
          if (file.existsSync()) {
            final lines = file.readAsLinesSync();
            for (var line in lines.skip(1)) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.length > 3) {
                final remAddr = parts[2];
                final state = parts[3];
                if (state == '01') { // ESTABLISHED
                   final hostPort = remAddr.split(':');
                   if (hostPort.length == 2) {
                     final portHex = hostPort[1];
                     final portInt = int.parse(portHex, radix: 16);
                     if (portInt == 5228 || portInt == 5229 || portInt == 5230) {
                        final ipHex = hostPort[0];
                        if (ipHex.length == 32) {
                          final ipParts = <String>[];
                          for(int i = 0; i < 32; i += 8) {
                             final group = ipHex.substring(i, i+8);
                             final part1 = group.substring(6,8) + group.substring(4,6);
                             final part2 = group.substring(2,4) + group.substring(0,2);
                             ipParts.add(part1);
                             ipParts.add(part2);
                          }
                          foundIp = ipParts.join(':');
                          port = portInt.toString();
                          isConnected = true;
                          break;
                        }
                     }
                   }
                }
              }
            }
          }
        } catch (_) {}
      }

      if (isConnected && foundIp != null) {
         try {
           final reverseInfo = await InternetAddress(foundIp).reverse();
           host = '${reverseInfo.host}/$foundIp';
         } catch (_) {
           host = 'mtalk.google.com/$foundIp';
         }
      }
    }

    if (mounted) {
      setState(() {
         _isConnected = isConnected;
         _host = host;
         _port = port;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: '$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(tr?.translate('fcm_status_title') ?? 'FCM Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open System FCM Diagnostics',
            onPressed: () {
              try {
                if (Platform.isAndroid) {
                  const AndroidIntent intent = AndroidIntent(
                    action: 'android.intent.action.MAIN',
                    package: 'com.google.android.gms',
                    componentName: 'com.google.android.gms.gcm.GcmDiagnostics',
                  );
                  intent.launch().catchError((e) {
                     Fluttertoast.showToast(msg: 'Failed to open system diagnostics');
                  });
                }
              } catch (_) {}
            },
          )
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr?.translate('fcm_environment') ?? 'Environment',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_google_service') ?? 'Google Service'),
            subtitle: Text(_isGoogleServiceEnabled 
              ? (tr?.translate('fcm_enabled') ?? 'Enabled') 
              : (tr?.translate('fcm_disabled') ?? 'Disabled')),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_vpn') ?? 'VPN'),
            subtitle: Text(_isVpnUsed 
              ? '${tr?.translate('fcm_yes') ?? 'Yes'} ($_vpnName)' 
              : (tr?.translate('fcm_none') ?? 'None')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr?.translate('fcm_status_title') ?? 'FCM Status',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_server') ?? 'Server'),
            subtitle: Text(_isConnected 
              ? (tr?.translate('fcm_connected') ?? 'Connected') 
              : (tr?.translate('fcm_disconnected') ?? 'Disconnected')),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_host') ?? 'Host'),
            subtitle: Text(_host),
            onLongPress: () => _copyToClipboard(_host, tr?.translate('fcm_host') ?? 'Host'),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_port') ?? 'Port'),
            subtitle: Text(_port),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_token') ?? 'FCM Token'),
            subtitle: Text(
              _fcmToken,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onLongPress: () => _copyToClipboard(_fcmToken, tr?.translate('fcm_token') ?? 'FCM Token'),
          ),
        ],
      ),
    );
  }
}