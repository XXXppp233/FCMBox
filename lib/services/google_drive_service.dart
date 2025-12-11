import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;

  final List<String> _scopes = [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ];

  Future<void> init() async {
    await GoogleSignIn.instance.initialize();

    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentUser = event.user;
        await _updateDriveApi(event.user);
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
        _driveApi = null;
      }
    });

    await GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  Future<void> _updateDriveApi(GoogleSignInAccount user) async {
    try {
      final authClient = user.authorizationClient;
      // Try silent authorization first
      var authz = await authClient.authorizationForScopes(_scopes);

      if (authz != null) {
        final httpClient = authz.authClient(scopes: _scopes);
        _driveApi = drive.DriveApi(httpClient);
      } else {
        _driveApi = null;
      }
    } catch (e) {
      debugPrint('Error setting up Drive API: $e');
      _driveApi = null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );

      // If _driveApi is still null after sign in, we might need to call authorizeScopes explicitly.
      if (_driveApi == null) {
        final authClient = account.authorizationClient;
        final authz = await authClient.authorizeScopes(_scopes);
        final httpClient = authz.authClient(scopes: _scopes);
        _driveApi = drive.DriveApi(httpClient);
      }

      return account;
    } catch (error) {
      debugPrint('Google Sign-In failed: $error');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }

  Future<String?> _getOrCreateFolder(String folderName) async {
    if (_driveApi == null) return null;

    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      final drive.File folderToCreate = drive.File();
      folderToCreate.name = folderName;
      folderToCreate.mimeType = 'application/vnd.google-apps.folder';

      final folder = await _driveApi!.files.create(folderToCreate);
      return folder.id;
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
      return null;
    }
  }

  Future<void> uploadData(String fileName, String content) async {
    if (_driveApi == null) return;

    try {
      final folderId = await _getOrCreateFolder('FCMBox');
      if (folderId == null) return;

      // Check if file exists to update it instead of creating duplicates
      final fileList = await _driveApi!.files.list(
        q: "name = '$fileName' and '$folderId' in parents and trashed = false",
      );

      final drive.File fileToUpload = drive.File();
      fileToUpload.name = fileName;
      // fileToUpload.parents = [folderId]; // Only needed for create

      final List<int> bytes = content.codeUnits;
      final drive.Media media = drive.Media(
        Future.value(bytes).asStream().asBroadcastStream(),
        bytes.length,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing file
        final fileId = fileList.files!.first.id!;
        await _driveApi!.files.update(fileToUpload, fileId, uploadMedia: media);
        debugPrint('File updated successfully');
      } else {
        // Create new file
        fileToUpload.parents = [folderId];
        await _driveApi!.files.create(fileToUpload, uploadMedia: media);
        debugPrint('File uploaded successfully');
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  // Placeholder for sync logic
  Future<void> syncData(String content) async {
    await uploadData('data.json', content);
  }
}
