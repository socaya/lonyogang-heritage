#!/usr/bin/env sh
set -eu
# Flutter generates native project shells; our audited Dart implementation lives in lib/.
flutter create --platforms=android,ios --project-name lonyogang_heritage --org com.vitalworks --no-pub .
mkdir -p android/app
cat > android/app/proguard-rules.pro <<'RULES'
-keep class net.sqlcipher.** { *; }
RULES
# Configure biometric system capabilities for Android after initial project generation.
# Android local_auth uses FragmentActivity for the biometric prompt.
python3 - <<'PY_NATIVE'
from pathlib import Path
for source in Path('android/app/src/main').rglob('MainActivity.kt'):
    s=source.read_text()
    s=s.replace('import io.flutter.embedding.android.FlutterActivity','import io.flutter.embedding.android.FlutterFragmentActivity')
    s=s.replace('FlutterActivity()', 'FlutterFragmentActivity()')
    source.write_text(s)
PY_NATIVE
python3 - <<'PY'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
if p.exists():
    s=p.read_text()
    if 'android.permission.USE_BIOMETRIC' not in s:
        s=s.replace('<application', '<uses-permission android:name="android.permission.USE_BIOMETRIC" />\n    <application',1)
    p.write_text(s)
# iOS Face ID consent usage statement
p=Path('ios/Runner/Info.plist')
if p.exists():
    s=p.read_text()
    if 'NSFaceIDUsageDescription' not in s:
        s=s.replace('</dict>', '<key>NSFaceIDUsageDescription</key>\n<string>Unlock your personal wealth vault with Face ID.</string>\n</dict>',1)
    p.write_text(s)
PY
