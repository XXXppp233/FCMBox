import 'package:flutter/material.dart';
import 'package:fcm_box/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Could not launch $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.about ?? 'About',
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          Center(
            child: Image.asset(
              'assets/icon/mode_heat.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppLocalizations.of(context)?.app_title ?? 'FCM Box',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (_version.isNotEmpty)
            Center(
              child: Text(
                'Version $_version',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 40),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub Repository'),
            subtitle: const Text(
              'https://docs.wepayto.win/application/fcmbox/',
            ),
            onTap: () {
              _launchUrl('https://github.com/XXXppp233/FCMBox');
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('View the Documentation'),
            subtitle: const Text(
              'https://docs.wepayto.win/application/fcmbox/',
            ),
            onTap: () {
              _launchUrl('https://docs.wepayto.win/application/fcmbox/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Report an Issue'),
            onTap: () {
              _launchUrl('https://github.com/XXXppp233/FCMBox/issues');
            },
          ),
        ],
      ),
    );
  }
}
