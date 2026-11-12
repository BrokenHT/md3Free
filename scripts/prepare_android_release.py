"""Prepare production Android registration after Flutter 3.47 `pub get`.

Usage: python scripts/prepare_android_release.py (requires PyYAML).
Run before `flutter build apk --release --flavor lite --no-pub`.
Flutter's integration_test development plugin must not enter release registration.
"""
import json
from pathlib import Path
import yaml

root = Path(__file__).resolve().parent.parent
plugins = json.loads((root / '.flutter-plugins-dependencies').read_text(encoding='utf-8'))['plugins']['android']
lines = ['package io.flutter.plugins;', 'import androidx.annotation.Keep;',
         'import androidx.annotation.NonNull;', 'import io.flutter.Log;',
         'import io.flutter.embedding.engine.FlutterEngine;',
         '@Keep public final class GeneratedPluginRegistrant {',
         ' public static void registerWith(@NonNull FlutterEngine engine) {']
count = 0
for plugin in plugins:
    if plugin.get('dev_dependency', False) or not plugin.get('native_build', False):
        continue
    manifest = yaml.safe_load((Path(plugin['path']) / 'pubspec.yaml').read_text(encoding='utf-8'))
    declaration = manifest['flutter']['plugin']
    android = declaration.get('platforms', {}).get('android', declaration)
    if not android.get('package') or not android.get('pluginClass'):
        continue
    implementation = android['package'] + '.' + android['pluginClass']
    lines.append('  try { engine.getPlugins().add(new ' + implementation + '()); } '
                 'catch (Exception e) { Log.e("GeneratedPluginRegistrant", "' + plugin['name'] + '", e); }')
    count += 1
lines += [' }', '}']
destination = root / 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'Registered {count} production Android plugins.')
