# Build and verify the mobile application

The app source is now committed on the public `main` branch at https://github.com/socaya/lonyogang-heritage.

```bash
git clone https://github.com/socaya/lonyogang-heritage.git
cd lonyogang-heritage
npm install
npm run check
npx expo install --check
npx expo start --android
```

For iOS development on macOS, run `npx expo start --ios` with a configured iOS simulator. Mobile UI is an Expo/React Native **demo prototype**, not a production service. Use only synthetic portfolio data: no authentication server or persistent encrypted ledger is currently connected.

## Visual fidelity checks

The approved target is a 6.7-inch Android device, approximately **1080 × 2400** pixels (20:9). Capture actual emulator/device screenshots and compare layout, fonts, safe areas, padding, flat backgrounds, card radii, navigation and contrast against the separately supplied reference PNG archive. The 13 original full-resolution modern reference screenshots are distributed in the user's downloadable source package rather than committed to this public repository. The original registration screen takes precedence over older illustration-heavy designs.

Use Theme 1: Midnight Navy, Antique Gold and Sage; the approved Acholi granary brand icon contains **no financial bars or arrows**. The approved `HERITAGE` text is directly beneath the `GANG` word.

## Commit future changes

```bash
git status
git add .
git commit -m "feat: describe the completed change"
git push origin main
```

The repository is initialized and writable; **do not** run `git init` or force-push over `main`. Check GitHub Actions before merging or releasing work.
