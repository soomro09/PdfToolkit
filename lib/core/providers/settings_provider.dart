import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class SettingsState {
  final bool notificationsEnabled;
  final int compressionLevel; // 0 = low, 1 = medium, 2 = high
  final String defaultOutputDirectory;
  final bool biometricLock;

  const SettingsState({
    this.notificationsEnabled = true,
    this.compressionLevel = 1,
    this.defaultOutputDirectory = 'Downloads',
    this.biometricLock = false,
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    int? compressionLevel,
    String? defaultOutputDirectory,
    bool? biometricLock,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      defaultOutputDirectory: defaultOutputDirectory ?? this.defaultOutputDirectory,
      biometricLock: biometricLock ?? this.biometricLock,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
      (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void toggleNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void setCompressionLevel(int level) {
    state = state.copyWith(compressionLevel: level);
  }

  void setDefaultOutputDirectory(String dir) {
    state = state.copyWith(defaultOutputDirectory: dir);
  }

  void toggleBiometricLock(bool value) {
    state = state.copyWith(biometricLock: value);
  }
}