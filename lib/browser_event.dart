// SPDX-License-Identifier: MIT

import 'package:freezed_annotation/freezed_annotation.dart';

part 'browser_event.freezed.dart';

@freezed
class BrowserEvent with _$BrowserEvent {
  const factory BrowserEvent.loadUrl(String url) = LoadUrl;
  const factory BrowserEvent.back() = Back;
  const factory BrowserEvent.forward() = Forward;
  const factory BrowserEvent.refresh() = Refresh;
}
