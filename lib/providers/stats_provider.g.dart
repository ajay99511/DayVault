// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StatsNotifier)
final statsProvider = StatsNotifierProvider._();

final class StatsNotifierProvider
    extends $AsyncNotifierProvider<StatsNotifier, JournalStats> {
  StatsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'statsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$statsNotifierHash();

  @$internal
  @override
  StatsNotifier create() => StatsNotifier();
}

String _$statsNotifierHash() => r'fa79931e01dc475e0b197a446e9e6cb27433870d';

abstract class _$StatsNotifier extends $AsyncNotifier<JournalStats> {
  FutureOr<JournalStats> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<JournalStats>, JournalStats>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<JournalStats>, JournalStats>,
        AsyncValue<JournalStats>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
