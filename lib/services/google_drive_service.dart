import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (_currentUser != null) {
        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _driveApi = drive.DriveApi(httpClient);
        }
      } else {
        _driveApi = null;
      }
    });
    await _googleSignIn.signInSilently();
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (error) {
      debugPrint('Google Sign-In failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<void> uploadData(String fileName, String content) async {
    if (_driveApi == null) return;

    try {
      final drive.File fileToUpload = drive.File();
      fileToUpload.name = fileName;
      fileToUpload.parents = ['appDataFolder'];

      final List<int> bytes = content.codeUnits;
      final drive.Media media = drive.Media(
          Future.value(bytes).asStream().asBroadcastStream(), bytes.length);

      await _driveApi!.files.create(
        fileToUpload,
        uploadMedia: media,
      );
      debugPrint('File uploaded successfully');
    } catch (e) {
      debugPrint('Error uploading file: $e');
    }
  }
  
  // Placeholder for sync logic
  Future<void> syncData() async {
    // Implement sync logic here
    await Future.delayed(const Duration(seconds: 2));
  }
}
