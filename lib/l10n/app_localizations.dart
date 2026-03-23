import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'FCM Box'**
  String get app_title;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @use_monet.
  ///
  /// In en, this message translates to:
  /// **'Use Monet Theme'**
  String get use_monet;

  /// No description provided for @theme_colors.
  ///
  /// In en, this message translates to:
  /// **'Theme Colors'**
  String get theme_colors;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @backend_status.
  ///
  /// In en, this message translates to:
  /// **'Backend Status'**
  String get backend_status;

  /// No description provided for @check_code_sample.
  ///
  /// In en, this message translates to:
  /// **'View a code sample'**
  String get check_code_sample;

  /// No description provided for @delete_old_data.
  ///
  /// In en, this message translates to:
  /// **'Delete old data after update'**
  String get delete_old_data;

  /// No description provided for @select_quantity.
  ///
  /// In en, this message translates to:
  /// **'Select Quantity'**
  String get select_quantity;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search_hint;

  /// No description provided for @use_android_monet_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use dynamic colors from your wallpaper'**
  String get use_android_monet_subtitle;

  /// No description provided for @theme_color_subtitle_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled when Monet is enabled'**
  String get theme_color_subtitle_disabled;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @pure_dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Pure Dark Mode'**
  String get pure_dark_mode;

  /// No description provided for @pure_dark_mode_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use pure black background in dark mode'**
  String get pure_dark_mode_subtitle;

  /// No description provided for @system_default.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get system_default;

  /// No description provided for @force_webview.
  ///
  /// In en, this message translates to:
  /// **'Force WebView'**
  String get force_webview;

  /// No description provided for @force_webview_subtitle.
  ///
  /// In en, this message translates to:
  /// **'or exclude the short text'**
  String get force_webview_subtitle;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @no_results.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get no_results;

  /// No description provided for @search_by_title.
  ///
  /// In en, this message translates to:
  /// **'Search by Title'**
  String get search_by_title;

  /// No description provided for @search_by_content.
  ///
  /// In en, this message translates to:
  /// **'Search by Content'**
  String get search_by_content;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @notification_permission.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission'**
  String get notification_permission;

  /// No description provided for @notification_permission_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow app to post notifications'**
  String get notification_permission_subtitle;

  /// No description provided for @permission_granted.
  ///
  /// In en, this message translates to:
  /// **'Permission already granted'**
  String get permission_granted;

  /// No description provided for @backend_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Backend not configured'**
  String get backend_not_configured;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @refresh_failed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed'**
  String get refresh_failed;

  /// No description provided for @token_registration_failed.
  ///
  /// In en, this message translates to:
  /// **'Token registration failed'**
  String get token_registration_failed;

  /// No description provided for @token_registration_success.
  ///
  /// In en, this message translates to:
  /// **'Token registration successful'**
  String get token_registration_success;

  /// No description provided for @token_registration_error.
  ///
  /// In en, this message translates to:
  /// **'Token registration error'**
  String get token_registration_error;

  /// No description provided for @fcm_status_title.
  ///
  /// In en, this message translates to:
  /// **'FCM Status'**
  String get fcm_status_title;

  /// No description provided for @fcm_token_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get token'**
  String get fcm_token_failed;

  /// No description provided for @fcm_error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get fcm_error_prefix;

  /// No description provided for @fcm_open_diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Open System FCM Diagnostics'**
  String get fcm_open_diagnostics;

  /// No description provided for @fcm_open_diagnostics_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open system diagnostics'**
  String get fcm_open_diagnostics_failed;

  /// No description provided for @copied_to_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied_to_clipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @request_api.
  ///
  /// In en, this message translates to:
  /// **'Request API'**
  String get request_api;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
