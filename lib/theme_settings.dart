import 'package:flutter/material.dart';

class ThemeSettings {
  final bool useMonet;
  final int colorValue;
  ThemeSettings(this.useMonet, this.colorValue);
}

final ValueNotifier<ThemeSettings> themeSettingsNotifier =
    ValueNotifier(ThemeSettings(false, Colors.deepPurple.value));
