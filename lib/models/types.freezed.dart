// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LocationData {
  String get name;
  double get latitude;
  double get longitude;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LocationDataCopyWith<LocationData> get copyWith =>
      _$LocationDataCopyWithImpl<LocationData>(
          this as LocationData, _$identity);

  /// Serializes this LocationData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LocationData &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, latitude, longitude);

  @override
  String toString() {
    return 'LocationData(name: $name, latitude: $latitude, longitude: $longitude)';
  }
}

/// @nodoc
abstract mixin class $LocationDataCopyWith<$Res> {
  factory $LocationDataCopyWith(
          LocationData value, $Res Function(LocationData) _then) =
      _$LocationDataCopyWithImpl;
  @useResult
  $Res call({String name, double latitude, double longitude});
}

/// @nodoc
class _$LocationDataCopyWithImpl<$Res> implements $LocationDataCopyWith<$Res> {
  _$LocationDataCopyWithImpl(this._self, this._then);

  final LocationData _self;
  final $Res Function(LocationData) _then;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [LocationData].
extension LocationDataPatterns on LocationData {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_LocationData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_LocationData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_LocationData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String name, double latitude, double longitude)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that.name, _that.latitude, _that.longitude);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String name, double latitude, double longitude) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData():
        return $default(_that.name, _that.latitude, _that.longitude);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String name, double latitude, double longitude)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that.name, _that.latitude, _that.longitude);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LocationData implements LocationData {
  const _LocationData(
      {required this.name, required this.latitude, required this.longitude});
  factory _LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);

  @override
  final String name;
  @override
  final double latitude;
  @override
  final double longitude;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LocationDataCopyWith<_LocationData> get copyWith =>
      __$LocationDataCopyWithImpl<_LocationData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LocationDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LocationData &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, latitude, longitude);

  @override
  String toString() {
    return 'LocationData(name: $name, latitude: $latitude, longitude: $longitude)';
  }
}

/// @nodoc
abstract mixin class _$LocationDataCopyWith<$Res>
    implements $LocationDataCopyWith<$Res> {
  factory _$LocationDataCopyWith(
          _LocationData value, $Res Function(_LocationData) _then) =
      __$LocationDataCopyWithImpl;
  @override
  @useResult
  $Res call({String name, double latitude, double longitude});
}

/// @nodoc
class __$LocationDataCopyWithImpl<$Res>
    implements _$LocationDataCopyWith<$Res> {
  __$LocationDataCopyWithImpl(this._self, this._then);

  final _LocationData _self;
  final $Res Function(_LocationData) _then;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(_LocationData(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$JournalEntry {
  String get id;
  EntryType get type;
  DateTime get date;
  String get headline;
  String get content;
  Mood get mood;
  String? get feeling;
  List<String> get tags;
  LocationData? get location;
  TimeBucket? get timeBucket;
  List<String> get images;
  bool get isSpotlight;

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JournalEntryCopyWith<JournalEntry> get copyWith =>
      _$JournalEntryCopyWithImpl<JournalEntry>(
          this as JournalEntry, _$identity);

  /// Serializes this JournalEntry to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JournalEntry &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.headline, headline) ||
                other.headline == headline) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.mood, mood) || other.mood == mood) &&
            (identical(other.feeling, feeling) || other.feeling == feeling) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.timeBucket, timeBucket) ||
                other.timeBucket == timeBucket) &&
            const DeepCollectionEquality().equals(other.images, images) &&
            (identical(other.isSpotlight, isSpotlight) ||
                other.isSpotlight == isSpotlight));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      date,
      headline,
      content,
      mood,
      feeling,
      const DeepCollectionEquality().hash(tags),
      location,
      timeBucket,
      const DeepCollectionEquality().hash(images),
      isSpotlight);

  @override
  String toString() {
    return 'JournalEntry(id: $id, type: $type, date: $date, headline: $headline, content: $content, mood: $mood, feeling: $feeling, tags: $tags, location: $location, timeBucket: $timeBucket, images: $images, isSpotlight: $isSpotlight)';
  }
}

/// @nodoc
abstract mixin class $JournalEntryCopyWith<$Res> {
  factory $JournalEntryCopyWith(
          JournalEntry value, $Res Function(JournalEntry) _then) =
      _$JournalEntryCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      EntryType type,
      DateTime date,
      String headline,
      String content,
      Mood mood,
      String? feeling,
      List<String> tags,
      LocationData? location,
      TimeBucket? timeBucket,
      List<String> images,
      bool isSpotlight});

  $LocationDataCopyWith<$Res>? get location;
}

/// @nodoc
class _$JournalEntryCopyWithImpl<$Res> implements $JournalEntryCopyWith<$Res> {
  _$JournalEntryCopyWithImpl(this._self, this._then);

  final JournalEntry _self;
  final $Res Function(JournalEntry) _then;

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? date = null,
    Object? headline = null,
    Object? content = null,
    Object? mood = null,
    Object? feeling = freezed,
    Object? tags = null,
    Object? location = freezed,
    Object? timeBucket = freezed,
    Object? images = null,
    Object? isSpotlight = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as EntryType,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      headline: null == headline
          ? _self.headline
          : headline // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      mood: null == mood
          ? _self.mood
          : mood // ignore: cast_nullable_to_non_nullable
              as Mood,
      feeling: freezed == feeling
          ? _self.feeling
          : feeling // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as LocationData?,
      timeBucket: freezed == timeBucket
          ? _self.timeBucket
          : timeBucket // ignore: cast_nullable_to_non_nullable
              as TimeBucket?,
      images: null == images
          ? _self.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isSpotlight: null == isSpotlight
          ? _self.isSpotlight
          : isSpotlight // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationDataCopyWith<$Res>? get location {
    if (_self.location == null) {
      return null;
    }

    return $LocationDataCopyWith<$Res>(_self.location!, (value) {
      return _then(_self.copyWith(location: value));
    });
  }
}

/// Adds pattern-matching-related methods to [JournalEntry].
extension JournalEntryPatterns on JournalEntry {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_JournalEntry value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalEntry() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_JournalEntry value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEntry():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_JournalEntry value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEntry() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            EntryType type,
            DateTime date,
            String headline,
            String content,
            Mood mood,
            String? feeling,
            List<String> tags,
            LocationData? location,
            TimeBucket? timeBucket,
            List<String> images,
            bool isSpotlight)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JournalEntry() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.date,
            _that.headline,
            _that.content,
            _that.mood,
            _that.feeling,
            _that.tags,
            _that.location,
            _that.timeBucket,
            _that.images,
            _that.isSpotlight);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            EntryType type,
            DateTime date,
            String headline,
            String content,
            Mood mood,
            String? feeling,
            List<String> tags,
            LocationData? location,
            TimeBucket? timeBucket,
            List<String> images,
            bool isSpotlight)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEntry():
        return $default(
            _that.id,
            _that.type,
            _that.date,
            _that.headline,
            _that.content,
            _that.mood,
            _that.feeling,
            _that.tags,
            _that.location,
            _that.timeBucket,
            _that.images,
            _that.isSpotlight);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            EntryType type,
            DateTime date,
            String headline,
            String content,
            Mood mood,
            String? feeling,
            List<String> tags,
            LocationData? location,
            TimeBucket? timeBucket,
            List<String> images,
            bool isSpotlight)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JournalEntry() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.date,
            _that.headline,
            _that.content,
            _that.mood,
            _that.feeling,
            _that.tags,
            _that.location,
            _that.timeBucket,
            _that.images,
            _that.isSpotlight);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JournalEntry implements JournalEntry {
  const _JournalEntry(
      {required this.id,
      required this.type,
      required this.date,
      required this.headline,
      required this.content,
      required this.mood,
      this.feeling,
      final List<String> tags = const [],
      this.location,
      this.timeBucket,
      final List<String> images = const [],
      this.isSpotlight = false})
      : _tags = tags,
        _images = images;
  factory _JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);

  @override
  final String id;
  @override
  final EntryType type;
  @override
  final DateTime date;
  @override
  final String headline;
  @override
  final String content;
  @override
  final Mood mood;
  @override
  final String? feeling;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final LocationData? location;
  @override
  final TimeBucket? timeBucket;
  final List<String> _images;
  @override
  @JsonKey()
  List<String> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  @JsonKey()
  final bool isSpotlight;

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JournalEntryCopyWith<_JournalEntry> get copyWith =>
      __$JournalEntryCopyWithImpl<_JournalEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JournalEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JournalEntry &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.headline, headline) ||
                other.headline == headline) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.mood, mood) || other.mood == mood) &&
            (identical(other.feeling, feeling) || other.feeling == feeling) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.timeBucket, timeBucket) ||
                other.timeBucket == timeBucket) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.isSpotlight, isSpotlight) ||
                other.isSpotlight == isSpotlight));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      date,
      headline,
      content,
      mood,
      feeling,
      const DeepCollectionEquality().hash(_tags),
      location,
      timeBucket,
      const DeepCollectionEquality().hash(_images),
      isSpotlight);

  @override
  String toString() {
    return 'JournalEntry(id: $id, type: $type, date: $date, headline: $headline, content: $content, mood: $mood, feeling: $feeling, tags: $tags, location: $location, timeBucket: $timeBucket, images: $images, isSpotlight: $isSpotlight)';
  }
}

/// @nodoc
abstract mixin class _$JournalEntryCopyWith<$Res>
    implements $JournalEntryCopyWith<$Res> {
  factory _$JournalEntryCopyWith(
          _JournalEntry value, $Res Function(_JournalEntry) _then) =
      __$JournalEntryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      EntryType type,
      DateTime date,
      String headline,
      String content,
      Mood mood,
      String? feeling,
      List<String> tags,
      LocationData? location,
      TimeBucket? timeBucket,
      List<String> images,
      bool isSpotlight});

  @override
  $LocationDataCopyWith<$Res>? get location;
}

/// @nodoc
class __$JournalEntryCopyWithImpl<$Res>
    implements _$JournalEntryCopyWith<$Res> {
  __$JournalEntryCopyWithImpl(this._self, this._then);

  final _JournalEntry _self;
  final $Res Function(_JournalEntry) _then;

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? date = null,
    Object? headline = null,
    Object? content = null,
    Object? mood = null,
    Object? feeling = freezed,
    Object? tags = null,
    Object? location = freezed,
    Object? timeBucket = freezed,
    Object? images = null,
    Object? isSpotlight = null,
  }) {
    return _then(_JournalEntry(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as EntryType,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      headline: null == headline
          ? _self.headline
          : headline // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      mood: null == mood
          ? _self.mood
          : mood // ignore: cast_nullable_to_non_nullable
              as Mood,
      feeling: freezed == feeling
          ? _self.feeling
          : feeling // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as LocationData?,
      timeBucket: freezed == timeBucket
          ? _self.timeBucket
          : timeBucket // ignore: cast_nullable_to_non_nullable
              as TimeBucket?,
      images: null == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isSpotlight: null == isSpotlight
          ? _self.isSpotlight
          : isSpotlight // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of JournalEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationDataCopyWith<$Res>? get location {
    if (_self.location == null) {
      return null;
    }

    return $LocationDataCopyWith<$Res>(_self.location!, (value) {
      return _then(_self.copyWith(location: value));
    });
  }
}

/// @nodoc
mixin _$RankedItem {
  String get id;
  int get rank;
  String get name;
  double get rating; // 0 – 5 star rating
  String get subtitle; // e.g. director, author, cuisine type
  String get notes; // free-form personal notes
  DateTime get dateAdded;

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RankedItemCopyWith<RankedItem> get copyWith =>
      _$RankedItemCopyWithImpl<RankedItem>(this as RankedItem, _$identity);

  /// Serializes this RankedItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RankedItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.dateAdded, dateAdded) ||
                other.dateAdded == dateAdded));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, rank, name, rating, subtitle, notes, dateAdded);

  @override
  String toString() {
    return 'RankedItem(id: $id, rank: $rank, name: $name, rating: $rating, subtitle: $subtitle, notes: $notes, dateAdded: $dateAdded)';
  }
}

/// @nodoc
abstract mixin class $RankedItemCopyWith<$Res> {
  factory $RankedItemCopyWith(
          RankedItem value, $Res Function(RankedItem) _then) =
      _$RankedItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      int rank,
      String name,
      double rating,
      String subtitle,
      String notes,
      DateTime dateAdded});
}

/// @nodoc
class _$RankedItemCopyWithImpl<$Res> implements $RankedItemCopyWith<$Res> {
  _$RankedItemCopyWithImpl(this._self, this._then);

  final RankedItem _self;
  final $Res Function(RankedItem) _then;

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? rank = null,
    Object? name = null,
    Object? rating = null,
    Object? subtitle = null,
    Object? notes = null,
    Object? dateAdded = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _self.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      subtitle: null == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      dateAdded: null == dateAdded
          ? _self.dateAdded
          : dateAdded // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [RankedItem].
extension RankedItemPatterns on RankedItem {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_RankedItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_RankedItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_RankedItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String id, int rank, String name, double rating,
            String subtitle, String notes, DateTime dateAdded)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(_that.id, _that.rank, _that.name, _that.rating,
            _that.subtitle, _that.notes, _that.dateAdded);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String id, int rank, String name, double rating,
            String subtitle, String notes, DateTime dateAdded)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem():
        return $default(_that.id, _that.rank, _that.name, _that.rating,
            _that.subtitle, _that.notes, _that.dateAdded);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String id, int rank, String name, double rating,
            String subtitle, String notes, DateTime dateAdded)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(_that.id, _that.rank, _that.name, _that.rating,
            _that.subtitle, _that.notes, _that.dateAdded);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RankedItem implements RankedItem {
  const _RankedItem(
      {required this.id,
      required this.rank,
      required this.name,
      this.rating = 0,
      this.subtitle = '',
      this.notes = '',
      required this.dateAdded});
  factory _RankedItem.fromJson(Map<String, dynamic> json) =>
      _$RankedItemFromJson(json);

  @override
  final String id;
  @override
  final int rank;
  @override
  final String name;
  @override
  @JsonKey()
  final double rating;
// 0 – 5 star rating
  @override
  @JsonKey()
  final String subtitle;
// e.g. director, author, cuisine type
  @override
  @JsonKey()
  final String notes;
// free-form personal notes
  @override
  final DateTime dateAdded;

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RankedItemCopyWith<_RankedItem> get copyWith =>
      __$RankedItemCopyWithImpl<_RankedItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RankedItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RankedItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.dateAdded, dateAdded) ||
                other.dateAdded == dateAdded));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, rank, name, rating, subtitle, notes, dateAdded);

  @override
  String toString() {
    return 'RankedItem(id: $id, rank: $rank, name: $name, rating: $rating, subtitle: $subtitle, notes: $notes, dateAdded: $dateAdded)';
  }
}

/// @nodoc
abstract mixin class _$RankedItemCopyWith<$Res>
    implements $RankedItemCopyWith<$Res> {
  factory _$RankedItemCopyWith(
          _RankedItem value, $Res Function(_RankedItem) _then) =
      __$RankedItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      int rank,
      String name,
      double rating,
      String subtitle,
      String notes,
      DateTime dateAdded});
}

/// @nodoc
class __$RankedItemCopyWithImpl<$Res> implements _$RankedItemCopyWith<$Res> {
  __$RankedItemCopyWithImpl(this._self, this._then);

  final _RankedItem _self;
  final $Res Function(_RankedItem) _then;

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? rank = null,
    Object? name = null,
    Object? rating = null,
    Object? subtitle = null,
    Object? notes = null,
    Object? dateAdded = null,
  }) {
    return _then(_RankedItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _self.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      subtitle: null == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      dateAdded: null == dateAdded
          ? _self.dateAdded
          : dateAdded // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
mixin _$RankingCategory {
  String get id;
  String get title;
  String get iconName;
  List<RankedItem> get items;
  bool get isFavorite;

  /// Create a copy of RankingCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RankingCategoryCopyWith<RankingCategory> get copyWith =>
      _$RankingCategoryCopyWithImpl<RankingCategory>(
          this as RankingCategory, _$identity);

  /// Serializes this RankingCategory to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RankingCategory &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, iconName,
      const DeepCollectionEquality().hash(items), isFavorite);

  @override
  String toString() {
    return 'RankingCategory(id: $id, title: $title, iconName: $iconName, items: $items, isFavorite: $isFavorite)';
  }
}

/// @nodoc
abstract mixin class $RankingCategoryCopyWith<$Res> {
  factory $RankingCategoryCopyWith(
          RankingCategory value, $Res Function(RankingCategory) _then) =
      _$RankingCategoryCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String iconName,
      List<RankedItem> items,
      bool isFavorite});
}

/// @nodoc
class _$RankingCategoryCopyWithImpl<$Res>
    implements $RankingCategoryCopyWith<$Res> {
  _$RankingCategoryCopyWithImpl(this._self, this._then);

  final RankingCategory _self;
  final $Res Function(RankingCategory) _then;

  /// Create a copy of RankingCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? iconName = null,
    Object? items = null,
    Object? isFavorite = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _self.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<RankedItem>,
      isFavorite: null == isFavorite
          ? _self.isFavorite
          : isFavorite // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [RankingCategory].
extension RankingCategoryPatterns on RankingCategory {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_RankingCategory value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_RankingCategory value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_RankingCategory value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String id, String title, String iconName,
            List<RankedItem> items, bool isFavorite)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String id, String title, String iconName,
            List<RankedItem> items, bool isFavorite)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory():
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String id, String title, String iconName,
            List<RankedItem> items, bool isFavorite)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RankingCategory implements RankingCategory {
  const _RankingCategory(
      {required this.id,
      required this.title,
      required this.iconName,
      final List<RankedItem> items = const [],
      this.isFavorite = false})
      : _items = items;
  factory _RankingCategory.fromJson(Map<String, dynamic> json) =>
      _$RankingCategoryFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String iconName;
  final List<RankedItem> _items;
  @override
  @JsonKey()
  List<RankedItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  @JsonKey()
  final bool isFavorite;

  /// Create a copy of RankingCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RankingCategoryCopyWith<_RankingCategory> get copyWith =>
      __$RankingCategoryCopyWithImpl<_RankingCategory>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RankingCategoryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RankingCategory &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, iconName,
      const DeepCollectionEquality().hash(_items), isFavorite);

  @override
  String toString() {
    return 'RankingCategory(id: $id, title: $title, iconName: $iconName, items: $items, isFavorite: $isFavorite)';
  }
}

/// @nodoc
abstract mixin class _$RankingCategoryCopyWith<$Res>
    implements $RankingCategoryCopyWith<$Res> {
  factory _$RankingCategoryCopyWith(
          _RankingCategory value, $Res Function(_RankingCategory) _then) =
      __$RankingCategoryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String iconName,
      List<RankedItem> items,
      bool isFavorite});
}

/// @nodoc
class __$RankingCategoryCopyWithImpl<$Res>
    implements _$RankingCategoryCopyWith<$Res> {
  __$RankingCategoryCopyWithImpl(this._self, this._then);

  final _RankingCategory _self;
  final $Res Function(_RankingCategory) _then;

  /// Create a copy of RankingCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? iconName = null,
    Object? items = null,
    Object? isFavorite = null,
  }) {
    return _then(_RankingCategory(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _self.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<RankedItem>,
      isFavorite: null == isFavorite
          ? _self.isFavorite
          : isFavorite // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$UserSettings {
  bool get securityEnabled;
  String get username;
  String get theme;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserSettingsCopyWith<UserSettings> get copyWith =>
      _$UserSettingsCopyWithImpl<UserSettings>(
          this as UserSettings, _$identity);

  /// Serializes this UserSettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserSettings &&
            (identical(other.securityEnabled, securityEnabled) ||
                other.securityEnabled == securityEnabled) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.theme, theme) || other.theme == theme));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, securityEnabled, username, theme);

  @override
  String toString() {
    return 'UserSettings(securityEnabled: $securityEnabled, username: $username, theme: $theme)';
  }
}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res> {
  factory $UserSettingsCopyWith(
          UserSettings value, $Res Function(UserSettings) _then) =
      _$UserSettingsCopyWithImpl;
  @useResult
  $Res call({bool securityEnabled, String username, String theme});
}

/// @nodoc
class _$UserSettingsCopyWithImpl<$Res> implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? securityEnabled = null,
    Object? username = null,
    Object? theme = null,
  }) {
    return _then(_self.copyWith(
      securityEnabled: null == securityEnabled
          ? _self.securityEnabled
          : securityEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      theme: null == theme
          ? _self.theme
          : theme // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_UserSettings value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_UserSettings value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_UserSettings value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(bool securityEnabled, String username, String theme)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that.securityEnabled, _that.username, _that.theme);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(bool securityEnabled, String username, String theme)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings():
        return $default(_that.securityEnabled, _that.username, _that.theme);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(bool securityEnabled, String username, String theme)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that.securityEnabled, _that.username, _that.theme);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _UserSettings implements UserSettings {
  const _UserSettings(
      {this.securityEnabled = false,
      this.username = 'Architect',
      this.theme = 'dark'});
  factory _UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  @override
  @JsonKey()
  final bool securityEnabled;
  @override
  @JsonKey()
  final String username;
  @override
  @JsonKey()
  final String theme;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserSettingsCopyWith<_UserSettings> get copyWith =>
      __$UserSettingsCopyWithImpl<_UserSettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserSettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserSettings &&
            (identical(other.securityEnabled, securityEnabled) ||
                other.securityEnabled == securityEnabled) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.theme, theme) || other.theme == theme));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, securityEnabled, username, theme);

  @override
  String toString() {
    return 'UserSettings(securityEnabled: $securityEnabled, username: $username, theme: $theme)';
  }
}

/// @nodoc
abstract mixin class _$UserSettingsCopyWith<$Res>
    implements $UserSettingsCopyWith<$Res> {
  factory _$UserSettingsCopyWith(
          _UserSettings value, $Res Function(_UserSettings) _then) =
      __$UserSettingsCopyWithImpl;
  @override
  @useResult
  $Res call({bool securityEnabled, String username, String theme});
}

/// @nodoc
class __$UserSettingsCopyWithImpl<$Res>
    implements _$UserSettingsCopyWith<$Res> {
  __$UserSettingsCopyWithImpl(this._self, this._then);

  final _UserSettings _self;
  final $Res Function(_UserSettings) _then;

  /// Create a copy of UserSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? securityEnabled = null,
    Object? username = null,
    Object? theme = null,
  }) {
    return _then(_UserSettings(
      securityEnabled: null == securityEnabled
          ? _self.securityEnabled
          : securityEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      theme: null == theme
          ? _self.theme
          : theme // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
