import 'package:flutter/material.dart';

class LocaleSettings {
  final Locale? locale;
  LocaleSettings(this.locale);
}

final ValueNotifier<LocaleSettings> localeSettingsNotifier =
    ValueNotifier(LocaleSettings(null));
