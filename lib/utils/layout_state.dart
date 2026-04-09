import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // <-- Wajib import ini

class LayoutState {
  static final LayoutState _instance = LayoutState._internal();
  factory LayoutState() => _instance;
  LayoutState._internal();

  // [UPDATE] Nilai awalnya sekarang otomatis!
  // kIsWeb akan otomatis bernilai TRUE jika dibuka di browser.
  // kIsWeb akan otomatis bernilai FALSE jika dibuka di Android/iOS.
  final ValueNotifier<bool> isDesktopMode = ValueNotifier<bool>(kIsWeb);

  void toggleMode() {
    isDesktopMode.value = !isDesktopMode.value;
  }
}