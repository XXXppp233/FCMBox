import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:android_intent_plus/android_intent.dart';

class FcmStatusPage extends StatefulWidget {
  const FcmStatusPage({super.key});

  @override
  State<FcmStatusPage> createState() => _FcmStatusPageState();
}

class _FcmStatusPageState extends State<FcmStatusPage> {
  bool _isGoogleServiceEnabled = true; // Assume true for now
  bool _isVpnUsed = false;
  String _vpnName = '';
  
  String _serverStatus = 'Connected';
  String _host = 'mtalk.google.com';
  String _port = '5228';
  String _fcmToken = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    // 1. Check VPN
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      bool hasVpn = false;
      String vpnName = '';
      for (var interface in interfaces) {
        if (interface.name.contains('tun') || 
            interface.name.contains('ppp') || 
            interface.name.contains('wg') || 
            interface.name.contains('tap')) {
          hasVpn = true;
          vpnName = interface.name;
          break;
        }
      }
      setState(() {
        _isVpnUsed = hasVpn;
        _vpnName = vpnName;
      });
    } catch (_) {}

    // 2. Fetch Token
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token ?? 'Failed to get token';
      });
    } catch (e) {
      setState(() {
        _fcmToken = 'Error: $e';
        _serverStatus = 'Disconnected';
      });
    }

    // 3. DNS Lookup
    try {
      final results = await InternetAddress.lookup('mtalk.google.com');
      if (results.isNotEmpty && results[0].rawAddress.isNotEmpty) {
         setState(() {
           _host = 'mtalk.google.com/${results[0].address}';
         });
      }
    } catch (_) {}
    
    if (Platform.isAndroid) {
      _parseTcpConnections();
    }
  }

  void _parseTcpConnections() {
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
                 final port = int.parse(portHex, radix: 16);
                 if (port == 5228 || port == 5229 || port == 5230) {
                    final ipHex = hostPort[0];
                    final ipParts = <int>[];
                    for(int i = 0; i < ipHex.length; i += 2) {
                       ipParts.add(int.parse(ipHex.substring(i, i+2), radix: 16));
                    }
                    if (ipParts.length == 4) {
                      final ip = '${ipParts[3]}.${ipParts[2]}.${ipParts[1]}.${ipParts[0]}';
                      setState(() {
                         _host = 'mtalk.google.com/$ip';
                         _port = port.toString();
                         _serverStatus = 'Connected';
                      });
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: '$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Status'),
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
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Environment',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Google Service', _isGoogleServiceEnabled ? '已启用' : 'Disabled'),
          _buildInfoRow('是否使用了VPN', _isVpnUsed ? 'Yes ($_vpnName)' : 'No'),
          const SizedBox(height: 24),
          Text(
            'FCM Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Server', _serverStatus),
          _buildCopyableRow('Host', _host),
          _buildInfoRow('Port', _port),
          _buildCopyableRow('FCM Token', _fcmToken, isToken: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(String title, String value, {bool isToken = false}) {
    return InkWell(
      onLongPress: () => _copyToClipboard(value, title),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: Text(
                value,
                style: isToken ? const TextStyle(fontSize: 12) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}