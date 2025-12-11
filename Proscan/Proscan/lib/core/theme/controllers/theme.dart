import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme.g.dart';

@riverpod
class ThemeController extends _$ThemeController {
  static const String _key = 'theme_mode'; // 'light', 'dark', 'system'

  @override
  FutureOr<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    if (saved == null) {
      // First launch: follow system
      return ThemeMode.system;
    }

    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  /// Toggle between Light and Dark only
  Future<void> toggleTheme() async {
    final current = state.value ?? ThemeMode.system;
    final newMode = current == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    state = AsyncData(newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newMode.name);
  }

  /// Set any mode: light, dark, system
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.value == mode) return;

    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Optional: Reset to system default
  Future<void> resetToSystem() async {
    state = const AsyncData(ThemeMode.system);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
