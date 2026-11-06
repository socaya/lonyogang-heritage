# Build, visually verify, then publish

```bash
unzip LonyoGang_Heritage_Mobile_App_Source.zip
cd lonyogang-heritage
npm install
npx expo install --check
npm run check
npx expo start --android
```

For pixel-matched quality checks, start an Android emulator using a 1080 × 2400 screen definition (or comparable 6.7-inch screen, 20:9), collect rendered screens and compare against `assets/reference/screens/`. Review measured native font sizes, safe areas, card spacing and contrast. The approved account registration image has precedence over any older illustration-heavy screen design.

## Publish after granting GitHub write permission

```bash
git init
git branch -M main
git add .
git commit -m "feat: initialize LonyoGang Heritage Expo mobile app and UI references"
git remote add origin https://github.com/socaya/lonyogang-heritage.git
git push -u origin main
```

The remote was empty at inspection time. If it is no longer empty, **fetch and reconcile** before any push; do not force-push existing work.