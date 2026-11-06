.PHONY: bootstrap check run apk
bootstrap:
	flutter create --platforms=android,ios --org com.lonyogang .
	flutter pub get
check:
	flutter analyze
	flutter test
run:
	flutter run
apk:
	flutter build apk --debug
