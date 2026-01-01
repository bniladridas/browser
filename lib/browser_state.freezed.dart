// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'browser_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BrowserState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BrowserState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserState()';
  }
}

/// @nodoc
class $BrowserStateCopyWith<$Res> {
  $BrowserStateCopyWith(BrowserState _, $Res Function(BrowserState) __);
}

/// Adds pattern-matching-related methods to [BrowserState].
extension BrowserStatePatterns on BrowserState {
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
    TResult Function(Idle value)? idle,
    TResult Function(Loading value)? loading,
    TResult Function(Success value)? success,
    TResult Function(BrowserError value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case Idle() when idle != null:
        return idle(_that);
      case Loading() when loading != null:
        return loading(_that);
      case Success() when success != null:
        return success(_that);
      case BrowserError() when error != null:
        return error(_that);
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
    required TResult Function(Idle value) idle,
    required TResult Function(Loading value) loading,
    required TResult Function(Success value) success,
    required TResult Function(BrowserError value) error,
  }) {
    final _that = this;
    switch (_that) {
      case Idle():
        return idle(_that);
      case Loading():
        return loading(_that);
      case Success():
        return success(_that);
      case BrowserError():
        return error(_that);
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
    TResult? Function(Idle value)? idle,
    TResult? Function(Loading value)? loading,
    TResult? Function(Success value)? success,
    TResult? Function(BrowserError value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case Idle() when idle != null:
        return idle(_that);
      case Loading() when loading != null:
        return loading(_that);
      case Success() when success != null:
        return success(_that);
      case BrowserError() when error != null:
        return error(_that);
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
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(String url)? success,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case Idle() when idle != null:
        return idle();
      case Loading() when loading != null:
        return loading();
      case Success() when success != null:
        return success(_that.url);
      case BrowserError() when error != null:
        return error(_that.message);
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
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(String url) success,
    required TResult Function(String message) error,
  }) {
    final _that = this;
    switch (_that) {
      case Idle():
        return idle();
      case Loading():
        return loading();
      case Success():
        return success(_that.url);
      case BrowserError():
        return error(_that.message);
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
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(String url)? success,
    TResult? Function(String message)? error,
  }) {
    final _that = this;
    switch (_that) {
      case Idle() when idle != null:
        return idle();
      case Loading() when loading != null:
        return loading();
      case Success() when success != null:
        return success(_that.url);
      case BrowserError() when error != null:
        return error(_that.message);
      case _:
        return null;
    }
  }
}

/// @nodoc

class Idle implements BrowserState {
  const Idle();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Idle);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserState.idle()';
  }
}

/// @nodoc

class Loading implements BrowserState {
  const Loading();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Loading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BrowserState.loading()';
  }
}

/// @nodoc

class Success implements BrowserState {
  const Success(this.url);

  final String url;

  /// Create a copy of BrowserState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SuccessCopyWith<Success> get copyWith =>
      _$SuccessCopyWithImpl<Success>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Success &&
            (identical(other.url, url) || other.url == url));
  }

  @override
  int get hashCode => Object.hash(runtimeType, url);

  @override
  String toString() {
    return 'BrowserState.success(url: $url)';
  }
}

/// @nodoc
abstract mixin class $SuccessCopyWith<$Res>
    implements $BrowserStateCopyWith<$Res> {
  factory $SuccessCopyWith(Success value, $Res Function(Success) _then) =
      _$SuccessCopyWithImpl;
  @useResult
  $Res call({String url});
}

/// @nodoc
class _$SuccessCopyWithImpl<$Res> implements $SuccessCopyWith<$Res> {
  _$SuccessCopyWithImpl(this._self, this._then);

  final Success _self;
  final $Res Function(Success) _then;

  /// Create a copy of BrowserState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? url = null,
  }) {
    return _then(Success(
      null == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class BrowserError implements BrowserState {
  const BrowserError(this.message);

  final String message;

  /// Create a copy of BrowserState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BrowserErrorCopyWith<BrowserError> get copyWith =>
      _$BrowserErrorCopyWithImpl<BrowserError>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BrowserError &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() {
    return 'BrowserState.error(message: $message)';
  }
}

/// @nodoc
abstract mixin class $BrowserErrorCopyWith<$Res>
    implements $BrowserStateCopyWith<$Res> {
  factory $BrowserErrorCopyWith(
          BrowserError value, $Res Function(BrowserError) _then) =
      _$BrowserErrorCopyWithImpl;
  @useResult
  $Res call({String message});
}

/// @nodoc
class _$BrowserErrorCopyWithImpl<$Res> implements $BrowserErrorCopyWith<$Res> {
  _$BrowserErrorCopyWithImpl(this._self, this._then);

  final BrowserError _self;
  final $Res Function(BrowserError) _then;

  /// Create a copy of BrowserState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
  }) {
    return _then(BrowserError(
      null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
