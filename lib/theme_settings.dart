import 'package:flutter/material.dart';

class ThemeSettings {
  final bool useMonet;
  final int colorValue;
  final ThemeMode themeMode;
  final bool usePureDark;
  ThemeSettings(
    this.useMonet,
    this.colorValue,
    this.themeMode,
    this.usePureDark,
  );
}

final ValueNotifier<ThemeSettings> themeSettingsNotifier = ValueNotifier(
  ThemeSettings(false, Colors.deepPurple.toARGB32(), ThemeMode.system, false),
);
