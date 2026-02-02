// SPDX-License-Identifier: MIT

import 'package:freezed_annotation/freezed_annotation.dart';

part 'browser_state.freezed.dart';

@freezed
class BrowserState with _$BrowserState {
  const factory BrowserState.idle() = Idle;
  const factory BrowserState.loading() = Loading;
  const factory BrowserState.success(String url) = Success;
  const factory BrowserState.error(String message) = BrowserError;
}
