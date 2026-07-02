import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsProvider = ChangeNotifierProvider<AppSettingsState>((ref) {
  return AppSettingsState();
});

class AppSettingsState extends ChangeNotifier {
  AppSettingsState() {
    _load();
  }

  static const _prefer3dKey = 'settings_prefer_3d';
  static const _twoFingerRotationKey = 'settings_two_finger_rotation';
  static const _topoBackgroundKey = 'settings_topo_background';

  bool loaded = false;
  bool prefer3d = false;
  bool twoFingerRotation = true;
  bool showTopoBackground = true;

  Future<void> _load() async {
    final store = await SharedPreferences.getInstance();
    prefer3d = store.getBool(_prefer3dKey) ?? false;
    twoFingerRotation = store.getBool(_twoFingerRotationKey) ?? true;
    showTopoBackground = store.getBool(_topoBackgroundKey) ?? true;
    loaded = true;
    notifyListeners();
  }

  Future<void> setPrefer3d(bool value) async {
    prefer3d = value;
    notifyListeners();
    final store = await SharedPreferences.getInstance();
    await store.setBool(_prefer3dKey, value);
  }

  Future<void> setTwoFingerRotation(bool value) async {
    twoFingerRotation = value;
    notifyListeners();
    final store = await SharedPreferences.getInstance();
    await store.setBool(_twoFingerRotationKey, value);
  }

  Future<void> setShowTopoBackground(bool value) async {
    showTopoBackground = value;
    notifyListeners();
    final store = await SharedPreferences.getInstance();
    await store.setBool(_topoBackgroundKey, value);
  }
}
