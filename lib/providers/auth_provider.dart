import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthState extends _$AuthState {
  @override
  bool build() => false;

  void authenticate() => state = true;

  void unauthenticate() => state = false;
}
