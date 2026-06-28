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
mixin _$ImageReference {
  /// The source identifier: asset ID, URL string, or absolute file path.
  String get source;

  /// How this image was sourced (determines rendering strategy).
  ImageSourceType get type;

  /// Optional display name or caption.
  String? get displayName;

  /// Create a copy of ImageReference
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageReferenceCopyWith<ImageReference> get copyWith =>
      _$ImageReferenceCopyWithImpl<ImageReference>(
          this as ImageReference, _$identity);

  /// Serializes this ImageReference to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageReference &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, source, type, displayName);

  @override
  String toString() {
    return 'ImageReference(source: $source, type: $type, displayName: $displayName)';
  }
}

/// @nodoc
abstract mixin class $ImageReferenceCopyWith<$Res> {
  factory $ImageReferenceCopyWith(
          ImageReference value, $Res Function(ImageReference) _then) =
      _$ImageReferenceCopyWithImpl;
  @useResult
  $Res call({String source, ImageSourceType type, String? displayName});
}

/// @nodoc
class _$ImageReferenceCopyWithImpl<$Res>
    implements $ImageReferenceCopyWith<$Res> {
  _$ImageReferenceCopyWithImpl(this._self, this._then);

  final ImageReference _self;
  final $Res Function(ImageReference) _then;

  /// Create a copy of ImageReference
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? source = null,
    Object? type = null,
    Object? displayName = freezed,
  }) {
    return _then(_self.copyWith(
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ImageSourceType,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ImageReference].
extension ImageReferencePatterns on ImageReference {
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
    TResult Function(_ImageReference value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageReference() when $default != null:
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
    TResult Function(_ImageReference value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageReference():
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
    TResult? Function(_ImageReference value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageReference() when $default != null:
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
    TResult Function(String source, ImageSourceType type, String? displayName)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageReference() when $default != null:
        return $default(_that.source, _that.type, _that.displayName);
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
    TResult Function(String source, ImageSourceType type, String? displayName)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageReference():
        return $default(_that.source, _that.type, _that.displayName);
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
    TResult? Function(String source, ImageSourceType type, String? displayName)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageReference() when $default != null:
        return $default(_that.source, _that.type, _that.displayName);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ImageReference implements ImageReference {
  const _ImageReference(
      {required this.source, required this.type, this.displayName});
  factory _ImageReference.fromJson(Map<String, dynamic> json) =>
      _$ImageReferenceFromJson(json);

  /// The source identifier: asset ID, URL string, or absolute file path.
  @override
  final String source;

  /// How this image was sourced (determines rendering strategy).
  @override
  final ImageSourceType type;

  /// Optional display name or caption.
  @override
  final String? displayName;

  /// Create a copy of ImageReference
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImageReferenceCopyWith<_ImageReference> get copyWith =>
      __$ImageReferenceCopyWithImpl<_ImageReference>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImageReferenceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ImageReference &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, source, type, displayName);

  @override
  String toString() {
    return 'ImageReference(source: $source, type: $type, displayName: $displayName)';
  }
}

/// @nodoc
abstract mixin class _$ImageReferenceCopyWith<$Res>
    implements $ImageReferenceCopyWith<$Res> {
  factory _$ImageReferenceCopyWith(
          _ImageReference value, $Res Function(_ImageReference) _then) =
      __$ImageReferenceCopyWithImpl;
  @override
  @useResult
  $Res call({String source, ImageSourceType type, String? displayName});
}

/// @nodoc
class __$ImageReferenceCopyWithImpl<$Res>
    implements _$ImageReferenceCopyWith<$Res> {
  __$ImageReferenceCopyWithImpl(this._self, this._then);

  final _ImageReference _self;
  final $Res Function(_ImageReference) _then;

  /// Create a copy of ImageReference
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? source = null,
    Object? type = null,
    Object? displayName = freezed,
  }) {
    return _then(_ImageReference(
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ImageSourceType,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$LocationData {
  String get name;

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
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name);

  @override
  String toString() {
    return 'LocationData(name: $name)';
  }
}

/// @nodoc
abstract mixin class $LocationDataCopyWith<$Res> {
  factory $LocationDataCopyWith(
          LocationData value, $Res Function(LocationData) _then) =
      _$LocationDataCopyWithImpl;
  @useResult
  $Res call({String name});
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
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
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
    TResult Function(String name)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that.name);
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
    TResult Function(String name) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData():
        return $default(_that.name);
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
    TResult? Function(String name)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LocationData() when $default != null:
        return $default(_that.name);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LocationData implements LocationData {
  const _LocationData({required this.name});
  factory _LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);

  @override
  final String name;

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
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name);

  @override
  String toString() {
    return 'LocationData(name: $name)';
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
  $Res call({String name});
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
  }) {
    return _then(_LocationData(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
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
  List<ImageReference> get images;
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
      List<ImageReference> images,
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
              as List<ImageReference>,
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
            List<ImageReference> images,
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
            List<ImageReference> images,
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
            List<ImageReference> images,
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
      final List<ImageReference> images = const [],
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
  final List<ImageReference> _images;
  @override
  @JsonKey()
  List<ImageReference> get images {
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
      List<ImageReference> images,
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
              as List<ImageReference>,
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
mixin _$RankSnapshot {
  DateTime get date;
  int get rank;

  /// Create a copy of RankSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RankSnapshotCopyWith<RankSnapshot> get copyWith =>
      _$RankSnapshotCopyWithImpl<RankSnapshot>(
          this as RankSnapshot, _$identity);

  /// Serializes this RankSnapshot to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RankSnapshot &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.rank, rank) || other.rank == rank));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, rank);

  @override
  String toString() {
    return 'RankSnapshot(date: $date, rank: $rank)';
  }
}

/// @nodoc
abstract mixin class $RankSnapshotCopyWith<$Res> {
  factory $RankSnapshotCopyWith(
          RankSnapshot value, $Res Function(RankSnapshot) _then) =
      _$RankSnapshotCopyWithImpl;
  @useResult
  $Res call({DateTime date, int rank});
}

/// @nodoc
class _$RankSnapshotCopyWithImpl<$Res> implements $RankSnapshotCopyWith<$Res> {
  _$RankSnapshotCopyWithImpl(this._self, this._then);

  final RankSnapshot _self;
  final $Res Function(RankSnapshot) _then;

  /// Create a copy of RankSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? rank = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      rank: null == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [RankSnapshot].
extension RankSnapshotPatterns on RankSnapshot {
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
    TResult Function(_RankSnapshot value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot() when $default != null:
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
    TResult Function(_RankSnapshot value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot():
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
    TResult? Function(_RankSnapshot value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot() when $default != null:
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
    TResult Function(DateTime date, int rank)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot() when $default != null:
        return $default(_that.date, _that.rank);
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
    TResult Function(DateTime date, int rank) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot():
        return $default(_that.date, _that.rank);
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
    TResult? Function(DateTime date, int rank)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankSnapshot() when $default != null:
        return $default(_that.date, _that.rank);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RankSnapshot implements RankSnapshot {
  const _RankSnapshot({required this.date, required this.rank});
  factory _RankSnapshot.fromJson(Map<String, dynamic> json) =>
      _$RankSnapshotFromJson(json);

  @override
  final DateTime date;
  @override
  final int rank;

  /// Create a copy of RankSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RankSnapshotCopyWith<_RankSnapshot> get copyWith =>
      __$RankSnapshotCopyWithImpl<_RankSnapshot>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RankSnapshotToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RankSnapshot &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.rank, rank) || other.rank == rank));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, rank);

  @override
  String toString() {
    return 'RankSnapshot(date: $date, rank: $rank)';
  }
}

/// @nodoc
abstract mixin class _$RankSnapshotCopyWith<$Res>
    implements $RankSnapshotCopyWith<$Res> {
  factory _$RankSnapshotCopyWith(
          _RankSnapshot value, $Res Function(_RankSnapshot) _then) =
      __$RankSnapshotCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime date, int rank});
}

/// @nodoc
class __$RankSnapshotCopyWithImpl<$Res>
    implements _$RankSnapshotCopyWith<$Res> {
  __$RankSnapshotCopyWithImpl(this._self, this._then);

  final _RankSnapshot _self;
  final $Res Function(_RankSnapshot) _then;

  /// Create a copy of RankSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? rank = null,
  }) {
    return _then(_RankSnapshot(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      rank: null == rank
          ? _self.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
    ));
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
  ImageReference?
      get image; // optional cover art (reference-only, like journal)
  List<RankSnapshot> get history;

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
                other.dateAdded == dateAdded) &&
            (identical(other.image, image) || other.image == image) &&
            const DeepCollectionEquality().equals(other.history, history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, rank, name, rating, subtitle,
      notes, dateAdded, image, const DeepCollectionEquality().hash(history));

  @override
  String toString() {
    return 'RankedItem(id: $id, rank: $rank, name: $name, rating: $rating, subtitle: $subtitle, notes: $notes, dateAdded: $dateAdded, image: $image, history: $history)';
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
      DateTime dateAdded,
      ImageReference? image,
      List<RankSnapshot> history});

  $ImageReferenceCopyWith<$Res>? get image;
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
    Object? image = freezed,
    Object? history = null,
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
      image: freezed == image
          ? _self.image
          : image // ignore: cast_nullable_to_non_nullable
              as ImageReference?,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<RankSnapshot>,
    ));
  }

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImageReferenceCopyWith<$Res>? get image {
    if (_self.image == null) {
      return null;
    }

    return $ImageReferenceCopyWith<$Res>(_self.image!, (value) {
      return _then(_self.copyWith(image: value));
    });
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
    TResult Function(
            String id,
            int rank,
            String name,
            double rating,
            String subtitle,
            String notes,
            DateTime dateAdded,
            ImageReference? image,
            List<RankSnapshot> history)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(
            _that.id,
            _that.rank,
            _that.name,
            _that.rating,
            _that.subtitle,
            _that.notes,
            _that.dateAdded,
            _that.image,
            _that.history);
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
            int rank,
            String name,
            double rating,
            String subtitle,
            String notes,
            DateTime dateAdded,
            ImageReference? image,
            List<RankSnapshot> history)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem():
        return $default(
            _that.id,
            _that.rank,
            _that.name,
            _that.rating,
            _that.subtitle,
            _that.notes,
            _that.dateAdded,
            _that.image,
            _that.history);
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
            int rank,
            String name,
            double rating,
            String subtitle,
            String notes,
            DateTime dateAdded,
            ImageReference? image,
            List<RankSnapshot> history)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankedItem() when $default != null:
        return $default(
            _that.id,
            _that.rank,
            _that.name,
            _that.rating,
            _that.subtitle,
            _that.notes,
            _that.dateAdded,
            _that.image,
            _that.history);
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
      required this.dateAdded,
      this.image,
      final List<RankSnapshot> history = const []})
      : _history = history;
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
  @override
  final ImageReference? image;
// optional cover art (reference-only, like journal)
  final List<RankSnapshot> _history;
// optional cover art (reference-only, like journal)
  @override
  @JsonKey()
  List<RankSnapshot> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

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
                other.dateAdded == dateAdded) &&
            (identical(other.image, image) || other.image == image) &&
            const DeepCollectionEquality().equals(other._history, _history));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, rank, name, rating, subtitle,
      notes, dateAdded, image, const DeepCollectionEquality().hash(_history));

  @override
  String toString() {
    return 'RankedItem(id: $id, rank: $rank, name: $name, rating: $rating, subtitle: $subtitle, notes: $notes, dateAdded: $dateAdded, image: $image, history: $history)';
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
      DateTime dateAdded,
      ImageReference? image,
      List<RankSnapshot> history});

  @override
  $ImageReferenceCopyWith<$Res>? get image;
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
    Object? image = freezed,
    Object? history = null,
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
      image: freezed == image
          ? _self.image
          : image // ignore: cast_nullable_to_non_nullable
              as ImageReference?,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<RankSnapshot>,
    ));
  }

  /// Create a copy of RankedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImageReferenceCopyWith<$Res>? get image {
    if (_self.image == null) {
      return null;
    }

    return $ImageReferenceCopyWith<$Res>(_self.image!, (value) {
      return _then(_self.copyWith(image: value));
    });
  }
}

/// @nodoc
mixin _$RankingCategory {
  String get id;
  String get title;
  String get iconName;
  List<RankedItem> get items;
  bool get isFavorite;
  int get colorValue;

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
                other.isFavorite == isFavorite) &&
            (identical(other.colorValue, colorValue) ||
                other.colorValue == colorValue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, iconName,
      const DeepCollectionEquality().hash(items), isFavorite, colorValue);

  @override
  String toString() {
    return 'RankingCategory(id: $id, title: $title, iconName: $iconName, items: $items, isFavorite: $isFavorite, colorValue: $colorValue)';
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
      bool isFavorite,
      int colorValue});
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
    Object? colorValue = null,
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
      colorValue: null == colorValue
          ? _self.colorValue
          : colorValue // ignore: cast_nullable_to_non_nullable
              as int,
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
            List<RankedItem> items, bool isFavorite, int colorValue)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite, _that.colorValue);
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
            List<RankedItem> items, bool isFavorite, int colorValue)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory():
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite, _that.colorValue);
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
            List<RankedItem> items, bool isFavorite, int colorValue)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RankingCategory() when $default != null:
        return $default(_that.id, _that.title, _that.iconName, _that.items,
            _that.isFavorite, _that.colorValue);
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
      this.isFavorite = false,
      this.colorValue = 0})
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
  @override
  @JsonKey()
  final int colorValue;

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
                other.isFavorite == isFavorite) &&
            (identical(other.colorValue, colorValue) ||
                other.colorValue == colorValue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, iconName,
      const DeepCollectionEquality().hash(_items), isFavorite, colorValue);

  @override
  String toString() {
    return 'RankingCategory(id: $id, title: $title, iconName: $iconName, items: $items, isFavorite: $isFavorite, colorValue: $colorValue)';
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
      bool isFavorite,
      int colorValue});
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
    Object? colorValue = null,
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
      colorValue: null == colorValue
          ? _self.colorValue
          : colorValue // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$VisionBoardItem {
  String get id;
  String get title;
  String get description;
  String get category;
  List<ImageReference> get images;
  bool get isAchieved;
  DateTime? get targetDate;
  DateTime get createdAt;
  int get colorAccent; // ARGB accent; 0 = use category default
  String get affirmation;

  /// Create a copy of VisionBoardItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VisionBoardItemCopyWith<VisionBoardItem> get copyWith =>
      _$VisionBoardItemCopyWithImpl<VisionBoardItem>(
          this as VisionBoardItem, _$identity);

  /// Serializes this VisionBoardItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VisionBoardItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other.images, images) &&
            (identical(other.isAchieved, isAchieved) ||
                other.isAchieved == isAchieved) &&
            (identical(other.targetDate, targetDate) ||
                other.targetDate == targetDate) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.colorAccent, colorAccent) ||
                other.colorAccent == colorAccent) &&
            (identical(other.affirmation, affirmation) ||
                other.affirmation == affirmation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      description,
      category,
      const DeepCollectionEquality().hash(images),
      isAchieved,
      targetDate,
      createdAt,
      colorAccent,
      affirmation);

  @override
  String toString() {
    return 'VisionBoardItem(id: $id, title: $title, description: $description, category: $category, images: $images, isAchieved: $isAchieved, targetDate: $targetDate, createdAt: $createdAt, colorAccent: $colorAccent, affirmation: $affirmation)';
  }
}

/// @nodoc
abstract mixin class $VisionBoardItemCopyWith<$Res> {
  factory $VisionBoardItemCopyWith(
          VisionBoardItem value, $Res Function(VisionBoardItem) _then) =
      _$VisionBoardItemCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String category,
      List<ImageReference> images,
      bool isAchieved,
      DateTime? targetDate,
      DateTime createdAt,
      int colorAccent,
      String affirmation});
}

/// @nodoc
class _$VisionBoardItemCopyWithImpl<$Res>
    implements $VisionBoardItemCopyWith<$Res> {
  _$VisionBoardItemCopyWithImpl(this._self, this._then);

  final VisionBoardItem _self;
  final $Res Function(VisionBoardItem) _then;

  /// Create a copy of VisionBoardItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? images = null,
    Object? isAchieved = null,
    Object? targetDate = freezed,
    Object? createdAt = null,
    Object? colorAccent = null,
    Object? affirmation = null,
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
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _self.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<ImageReference>,
      isAchieved: null == isAchieved
          ? _self.isAchieved
          : isAchieved // ignore: cast_nullable_to_non_nullable
              as bool,
      targetDate: freezed == targetDate
          ? _self.targetDate
          : targetDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      colorAccent: null == colorAccent
          ? _self.colorAccent
          : colorAccent // ignore: cast_nullable_to_non_nullable
              as int,
      affirmation: null == affirmation
          ? _self.affirmation
          : affirmation // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [VisionBoardItem].
extension VisionBoardItemPatterns on VisionBoardItem {
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
    TResult Function(_VisionBoardItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem() when $default != null:
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
    TResult Function(_VisionBoardItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem():
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
    TResult? Function(_VisionBoardItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem() when $default != null:
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
            String title,
            String description,
            String category,
            List<ImageReference> images,
            bool isAchieved,
            DateTime? targetDate,
            DateTime createdAt,
            int colorAccent,
            String affirmation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.description,
            _that.category,
            _that.images,
            _that.isAchieved,
            _that.targetDate,
            _that.createdAt,
            _that.colorAccent,
            _that.affirmation);
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
            String title,
            String description,
            String category,
            List<ImageReference> images,
            bool isAchieved,
            DateTime? targetDate,
            DateTime createdAt,
            int colorAccent,
            String affirmation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem():
        return $default(
            _that.id,
            _that.title,
            _that.description,
            _that.category,
            _that.images,
            _that.isAchieved,
            _that.targetDate,
            _that.createdAt,
            _that.colorAccent,
            _that.affirmation);
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
            String title,
            String description,
            String category,
            List<ImageReference> images,
            bool isAchieved,
            DateTime? targetDate,
            DateTime createdAt,
            int colorAccent,
            String affirmation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoardItem() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.description,
            _that.category,
            _that.images,
            _that.isAchieved,
            _that.targetDate,
            _that.createdAt,
            _that.colorAccent,
            _that.affirmation);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VisionBoardItem implements VisionBoardItem {
  const _VisionBoardItem(
      {required this.id,
      required this.title,
      this.description = '',
      this.category = '',
      final List<ImageReference> images = const [],
      this.isAchieved = false,
      this.targetDate,
      required this.createdAt,
      this.colorAccent = 0,
      this.affirmation = ''})
      : _images = images;
  factory _VisionBoardItem.fromJson(Map<String, dynamic> json) =>
      _$VisionBoardItemFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final String category;
  final List<ImageReference> _images;
  @override
  @JsonKey()
  List<ImageReference> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  @JsonKey()
  final bool isAchieved;
  @override
  final DateTime? targetDate;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final int colorAccent;
// ARGB accent; 0 = use category default
  @override
  @JsonKey()
  final String affirmation;

  /// Create a copy of VisionBoardItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VisionBoardItemCopyWith<_VisionBoardItem> get copyWith =>
      __$VisionBoardItemCopyWithImpl<_VisionBoardItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VisionBoardItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VisionBoardItem &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.isAchieved, isAchieved) ||
                other.isAchieved == isAchieved) &&
            (identical(other.targetDate, targetDate) ||
                other.targetDate == targetDate) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.colorAccent, colorAccent) ||
                other.colorAccent == colorAccent) &&
            (identical(other.affirmation, affirmation) ||
                other.affirmation == affirmation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      description,
      category,
      const DeepCollectionEquality().hash(_images),
      isAchieved,
      targetDate,
      createdAt,
      colorAccent,
      affirmation);

  @override
  String toString() {
    return 'VisionBoardItem(id: $id, title: $title, description: $description, category: $category, images: $images, isAchieved: $isAchieved, targetDate: $targetDate, createdAt: $createdAt, colorAccent: $colorAccent, affirmation: $affirmation)';
  }
}

/// @nodoc
abstract mixin class _$VisionBoardItemCopyWith<$Res>
    implements $VisionBoardItemCopyWith<$Res> {
  factory _$VisionBoardItemCopyWith(
          _VisionBoardItem value, $Res Function(_VisionBoardItem) _then) =
      __$VisionBoardItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String description,
      String category,
      List<ImageReference> images,
      bool isAchieved,
      DateTime? targetDate,
      DateTime createdAt,
      int colorAccent,
      String affirmation});
}

/// @nodoc
class __$VisionBoardItemCopyWithImpl<$Res>
    implements _$VisionBoardItemCopyWith<$Res> {
  __$VisionBoardItemCopyWithImpl(this._self, this._then);

  final _VisionBoardItem _self;
  final $Res Function(_VisionBoardItem) _then;

  /// Create a copy of VisionBoardItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? images = null,
    Object? isAchieved = null,
    Object? targetDate = freezed,
    Object? createdAt = null,
    Object? colorAccent = null,
    Object? affirmation = null,
  }) {
    return _then(_VisionBoardItem(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<ImageReference>,
      isAchieved: null == isAchieved
          ? _self.isAchieved
          : isAchieved // ignore: cast_nullable_to_non_nullable
              as bool,
      targetDate: freezed == targetDate
          ? _self.targetDate
          : targetDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      colorAccent: null == colorAccent
          ? _self.colorAccent
          : colorAccent // ignore: cast_nullable_to_non_nullable
              as int,
      affirmation: null == affirmation
          ? _self.affirmation
          : affirmation // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$VisionBoard {
  String get id;
  int get year;
  List<VisionBoardItem> get items;
  DateTime get createdAt;

  /// Create a copy of VisionBoard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VisionBoardCopyWith<VisionBoard> get copyWith =>
      _$VisionBoardCopyWithImpl<VisionBoard>(this as VisionBoard, _$identity);

  /// Serializes this VisionBoard to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VisionBoard &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.year, year) || other.year == year) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, year,
      const DeepCollectionEquality().hash(items), createdAt);

  @override
  String toString() {
    return 'VisionBoard(id: $id, year: $year, items: $items, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $VisionBoardCopyWith<$Res> {
  factory $VisionBoardCopyWith(
          VisionBoard value, $Res Function(VisionBoard) _then) =
      _$VisionBoardCopyWithImpl;
  @useResult
  $Res call(
      {String id, int year, List<VisionBoardItem> items, DateTime createdAt});
}

/// @nodoc
class _$VisionBoardCopyWithImpl<$Res> implements $VisionBoardCopyWith<$Res> {
  _$VisionBoardCopyWithImpl(this._self, this._then);

  final VisionBoard _self;
  final $Res Function(VisionBoard) _then;

  /// Create a copy of VisionBoard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? year = null,
    Object? items = null,
    Object? createdAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _self.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<VisionBoardItem>,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [VisionBoard].
extension VisionBoardPatterns on VisionBoard {
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
    TResult Function(_VisionBoard value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VisionBoard() when $default != null:
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
    TResult Function(_VisionBoard value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoard():
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
    TResult? Function(_VisionBoard value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoard() when $default != null:
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
    TResult Function(String id, int year, List<VisionBoardItem> items,
            DateTime createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VisionBoard() when $default != null:
        return $default(_that.id, _that.year, _that.items, _that.createdAt);
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
    TResult Function(String id, int year, List<VisionBoardItem> items,
            DateTime createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoard():
        return $default(_that.id, _that.year, _that.items, _that.createdAt);
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
    TResult? Function(String id, int year, List<VisionBoardItem> items,
            DateTime createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VisionBoard() when $default != null:
        return $default(_that.id, _that.year, _that.items, _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VisionBoard implements VisionBoard {
  const _VisionBoard(
      {required this.id,
      required this.year,
      final List<VisionBoardItem> items = const [],
      required this.createdAt})
      : _items = items;
  factory _VisionBoard.fromJson(Map<String, dynamic> json) =>
      _$VisionBoardFromJson(json);

  @override
  final String id;
  @override
  final int year;
  final List<VisionBoardItem> _items;
  @override
  @JsonKey()
  List<VisionBoardItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final DateTime createdAt;

  /// Create a copy of VisionBoard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VisionBoardCopyWith<_VisionBoard> get copyWith =>
      __$VisionBoardCopyWithImpl<_VisionBoard>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VisionBoardToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VisionBoard &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.year, year) || other.year == year) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, year,
      const DeepCollectionEquality().hash(_items), createdAt);

  @override
  String toString() {
    return 'VisionBoard(id: $id, year: $year, items: $items, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$VisionBoardCopyWith<$Res>
    implements $VisionBoardCopyWith<$Res> {
  factory _$VisionBoardCopyWith(
          _VisionBoard value, $Res Function(_VisionBoard) _then) =
      __$VisionBoardCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id, int year, List<VisionBoardItem> items, DateTime createdAt});
}

/// @nodoc
class __$VisionBoardCopyWithImpl<$Res> implements _$VisionBoardCopyWith<$Res> {
  __$VisionBoardCopyWithImpl(this._self, this._then);

  final _VisionBoard _self;
  final $Res Function(_VisionBoard) _then;

  /// Create a copy of VisionBoard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? year = null,
    Object? items = null,
    Object? createdAt = null,
  }) {
    return _then(_VisionBoard(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _self.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<VisionBoardItem>,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
mixin _$UserSettings {
  bool get securityEnabled;
  bool get biometricsEnabled;
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
            (identical(other.biometricsEnabled, biometricsEnabled) ||
                other.biometricsEnabled == biometricsEnabled) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.theme, theme) || other.theme == theme));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, securityEnabled, biometricsEnabled, username, theme);

  @override
  String toString() {
    return 'UserSettings(securityEnabled: $securityEnabled, biometricsEnabled: $biometricsEnabled, username: $username, theme: $theme)';
  }
}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res> {
  factory $UserSettingsCopyWith(
          UserSettings value, $Res Function(UserSettings) _then) =
      _$UserSettingsCopyWithImpl;
  @useResult
  $Res call(
      {bool securityEnabled,
      bool biometricsEnabled,
      String username,
      String theme});
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
    Object? biometricsEnabled = null,
    Object? username = null,
    Object? theme = null,
  }) {
    return _then(_self.copyWith(
      securityEnabled: null == securityEnabled
          ? _self.securityEnabled
          : securityEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      biometricsEnabled: null == biometricsEnabled
          ? _self.biometricsEnabled
          : biometricsEnabled // ignore: cast_nullable_to_non_nullable
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
    TResult Function(bool securityEnabled, bool biometricsEnabled,
            String username, String theme)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that.securityEnabled, _that.biometricsEnabled,
            _that.username, _that.theme);
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
    TResult Function(bool securityEnabled, bool biometricsEnabled,
            String username, String theme)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings():
        return $default(_that.securityEnabled, _that.biometricsEnabled,
            _that.username, _that.theme);
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
    TResult? Function(bool securityEnabled, bool biometricsEnabled,
            String username, String theme)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserSettings() when $default != null:
        return $default(_that.securityEnabled, _that.biometricsEnabled,
            _that.username, _that.theme);
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
      this.biometricsEnabled = false,
      this.username = 'Architect',
      this.theme = 'dark'});
  factory _UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  @override
  @JsonKey()
  final bool securityEnabled;
  @override
  @JsonKey()
  final bool biometricsEnabled;
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
            (identical(other.biometricsEnabled, biometricsEnabled) ||
                other.biometricsEnabled == biometricsEnabled) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.theme, theme) || other.theme == theme));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, securityEnabled, biometricsEnabled, username, theme);

  @override
  String toString() {
    return 'UserSettings(securityEnabled: $securityEnabled, biometricsEnabled: $biometricsEnabled, username: $username, theme: $theme)';
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
  $Res call(
      {bool securityEnabled,
      bool biometricsEnabled,
      String username,
      String theme});
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
    Object? biometricsEnabled = null,
    Object? username = null,
    Object? theme = null,
  }) {
    return _then(_UserSettings(
      securityEnabled: null == securityEnabled
          ? _self.securityEnabled
          : securityEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      biometricsEnabled: null == biometricsEnabled
          ? _self.biometricsEnabled
          : biometricsEnabled // ignore: cast_nullable_to_non_nullable
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
