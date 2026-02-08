import 'package:flutter/material.dart';
import 'package:fcm_box/localization.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('about') ?? 'About',
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          const CircleAvatar(
            radius: 48,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage('assets/icon/app_icon.png'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppLocalizations.of(context)?.translate('app_title') ?? 'FCM Box',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
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
            subtitle: const Text('https://github.com/XXXppp233/FCMBox'),
            onTap: () {
              _launchUrl('https://github.com/XXXppp233/FCMBox');
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
