// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'browser_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BrowserEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BrowserEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserEvent()';
  }
}

/// @nodoc
class $BrowserEventCopyWith<$Res> {
  $BrowserEventCopyWith(BrowserEvent _, $Res Function(BrowserEvent) __);
}

/// Adds pattern-matching-related methods to [BrowserEvent].
extension BrowserEventPatterns on BrowserEvent {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(LoadUrl value)? loadUrl,
    TResult Function(Back value)? back,
    TResult Function(Forward value)? forward,
    TResult Function(Refresh value)? refresh,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl() when loadUrl != null:
        return loadUrl(_that);
      case Back() when back != null:
        return back(_that);
      case Forward() when forward != null:
        return forward(_that);
      case Refresh() when refresh != null:
        return refresh(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(LoadUrl value) loadUrl,
    required TResult Function(Back value) back,
    required TResult Function(Forward value) forward,
    required TResult Function(Refresh value) refresh,
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl():
        return loadUrl(_that);
      case Back():
        return back(_that);
      case Forward():
        return forward(_that);
      case Refresh():
        return refresh(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(LoadUrl value)? loadUrl,
    TResult? Function(Back value)? back,
    TResult? Function(Forward value)? forward,
    TResult? Function(Refresh value)? refresh,
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl() when loadUrl != null:
        return loadUrl(_that);
      case Back() when back != null:
        return back(_that);
      case Forward() when forward != null:
        return forward(_that);
      case Refresh() when refresh != null:
        return refresh(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String url)? loadUrl,
    TResult Function()? back,
    TResult Function()? forward,
    TResult Function()? refresh,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl() when loadUrl != null:
        return loadUrl(_that.url);
      case Back() when back != null:
        return back();
      case Forward() when forward != null:
        return forward();
      case Refresh() when refresh != null:
        return refresh();
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
  TResult when<TResult extends Object?>({
    required TResult Function(String url) loadUrl,
    required TResult Function() back,
    required TResult Function() forward,
    required TResult Function() refresh,
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl():
        return loadUrl(_that.url);
      case Back():
        return back();
      case Forward():
        return forward();
      case Refresh():
        return refresh();
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String url)? loadUrl,
    TResult? Function()? back,
    TResult? Function()? forward,
    TResult? Function()? refresh,
  }) {
    final _that = this;
    switch (_that) {
      case LoadUrl() when loadUrl != null:
        return loadUrl(_that.url);
      case Back() when back != null:
        return back();
      case Forward() when forward != null:
        return forward();
      case Refresh() when refresh != null:
        return refresh();
      case _:
        return null;
    }
  }
}

/// @nodoc

class LoadUrl implements BrowserEvent {
  const LoadUrl(this.url);

  final String url;

  /// Create a copy of BrowserEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LoadUrlCopyWith<LoadUrl> get copyWith =>
      _$LoadUrlCopyWithImpl<LoadUrl>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LoadUrl &&
            (identical(other.url, url) || other.url == url));
  }

  @override
  int get hashCode => Object.hash(runtimeType, url);

  @override
  String toString() {
    return 'BrowserEvent.loadUrl(url: $url)';
  }
}

/// @nodoc
abstract mixin class $LoadUrlCopyWith<$Res>
    implements $BrowserEventCopyWith<$Res> {
  factory $LoadUrlCopyWith(LoadUrl value, $Res Function(LoadUrl) _then) =
      _$LoadUrlCopyWithImpl;
  @useResult
  $Res call({String url});
}

/// @nodoc
class _$LoadUrlCopyWithImpl<$Res> implements $LoadUrlCopyWith<$Res> {
  _$LoadUrlCopyWithImpl(this._self, this._then);

  final LoadUrl _self;
  final $Res Function(LoadUrl) _then;

  /// Create a copy of BrowserEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? url = null,
  }) {
    return _then(LoadUrl(
      null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class Back implements BrowserEvent {
  const Back();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Back);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserEvent.back()';
  }
}

/// @nodoc

class Forward implements BrowserEvent {
  const Forward();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Forward);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserEvent.forward()';
  }
}

/// @nodoc

class Refresh implements BrowserEvent {
  const Refresh();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Refresh);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserEvent.refresh()';
  }
}

// dart format on
