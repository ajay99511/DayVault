import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';

/// Top-level PBKDF2 (HMAC-SHA256) derivation, shared by the app-lock
/// [SecurityService] and the privacy-vault [VaultSecurityService].
///
/// Must stay a top-level function so it can run in an isolate via compute().
/// params: {'pin': String, 'salt': String, 'iterations': int, 'keyLength': int}
Uint8List pbkdf2Derive(Map<String, dynamic> params) {
  final pin = params['pin'] as String;
  final salt = params['salt'] as String;
  final iterations = params['iterations'] as int;
  final keyLength = params['keyLength'] as int;

  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(
    Uint8List.fromList(utf8.encode(salt)),
    iterations,
    keyLength,
  ));
  return derivator.process(Uint8List.fromList(utf8.encode(pin)));
}
