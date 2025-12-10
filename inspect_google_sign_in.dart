import 'dart:mirrors';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  final mirror = reflectClass(GoogleSignIn);
  for (var declaration in mirror.declarations.values) {
    if (declaration is MethodMirror && declaration.isConstructor) {
      print('Constructor: ${declaration.simpleName}');
    }
  }
}
