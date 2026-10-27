import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/services/core_download_service.dart';
import 'package:moonfin/util/game_cores.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SupportDirectory extends PathProviderPlatform {
  _SupportDirectory(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PreferenceStore store;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    temporary = Directory.systemTemp.createTempSync('moonfin-core-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SupportDirectory(temporary.path);
    SharedPreferences.setMockInitialValues({});
    store = PreferenceStore();
    await store.init();
    await store.setStringList(installedCoresPreferenceKey, ['gambatte', 'snes9x']);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  test('managed installation ignores stale download preferences and files', () async {
    final downloads = await coresDirectory();
    await downloads.create(recursive: true);
    final stale = File('${downloads.path}/${coreFileName('gambatte')}');
    await stale.writeAsString('previously downloaded core');

    expect(nativeCoreReachable('nes'), isTrue);
    expect(nativeCoreReachable('gb'), isFalse);
    expect(nativeCoreReachable('snes'), isFalse);
    expect(await installedCorePath('gambatte'), isNull);
    expect(await installedCorePath('snes9x'), isNull);
    expect(CoreDownloadService(store).installed, unorderedEquals(['fceumm', 'ppsspp']));
    expect(await stale.readAsString(), 'previously downloaded core');
  });

  test('managed core cannot be removed or replaced through downloader', () async {
    final service = CoreDownloadService(store);
    final installedPath = await installedCorePath('fceumm');
    expect(installedPath, isNotNull);
    await expectLater(service.remove('fceumm'), throwsStateError);
    await expectLater(service.download('fceumm'), throwsStateError);
    expect(await installedCorePath('fceumm'), installedPath);
    expect(store.getStringList(installedCoresPreferenceKey), ['gambatte', 'snes9x']);
  });

  test('packaged PSP assets satisfy support installation without downloads', () async {
    final system = await systemDirectoryForCore('ppsspp');
    expect(await File('${system.path}/PPSSPP/compat.ini').exists(), isTrue);
    expect(await coreSupportFilesInstalled('ppsspp'), isTrue);
    await CoreDownloadService(store).installSupportFiles('ppsspp');
    expect(await temporary.list().isEmpty, isTrue);
  });
}
