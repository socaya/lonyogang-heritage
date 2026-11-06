# Flutter development and verification

Prerequisites: Flutter SDK stable 3.47 or later, Android Studio/SDK and for iOS Xcode/CocoaPods on macOS.

```bash
git clone https://github.com/socaya/lonyogang-heritage.git
cd lonyogang-heritage
bash tool/setup_platform.sh
flutter pub get
flutter analyze
flutter test
flutter run -d android
# for local Android APK:
flutter build apk --debug
```

`tool/setup_platform.sh` generates Android/iOS hosts with application ID `com.vitalworks.lonyogang_heritage`, inserts the Android biometric permission, configures a fragment activity for the biometric prompt, and sets the iOS Face ID usage description. Real-release bundle ID, signing certificate, provisioning profile and store configuration require product-owner confirmation.

GitHub Actions executes source analysis, tests and a debug APK build; download the APK from the successful `Flutter Android CI` workflow artifact.

**Visual acceptance:** capture Android screenshots at 6.7-inch/20:9 equivalent (1080 × 2400 reference), check actual device font scaling, app bar and tab behavior, navigation, content clipping and responsive insets. Compare to the approved Theme 1 modern flat account-creation screenshot and the 10-screen visual set. Screenshot agreement is not established by a successful compiler alone.

**Do not add Node/Expo dependencies:** this project uses Dart + Flutter, with no React Native runtime.

Release signing and backend sync are deliberately excluded until appropriate device, security and platform review. Do not advertise cloud recovery, OTP, investments execution or regulated services that are not implemented.
