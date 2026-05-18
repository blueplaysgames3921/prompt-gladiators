.PHONY: get gen build test clean run-macos run-windows run-linux run-android run-ios

# Install dependencies
get:
	flutter pub get

# Run code generation (freezed + riverpod)
gen:
	dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
gen-watch:
	dart run build_runner watch --delete-conflicting-outputs

# Run tests
test:
	flutter test

# Run tests with coverage
test-cover:
	flutter test --coverage
	genhtml coverage/lcov.info -o coverage/html
	@echo "Coverage: coverage/html/index.html"

# Lint
lint:
	flutter analyze

# Format
fmt:
	dart format lib/ test/

# Desktop targets
run-macos:
	flutter run -d macos

run-windows:
	flutter run -d windows

run-linux:
	flutter run -d linux

# Mobile targets
run-android:
	flutter run -d android

run-ios:
	flutter run -d ios

# Build release
build-macos:
	flutter build macos --release

build-windows:
	flutter build windows --release

build-linux:
	flutter build linux --release

build-android:
	flutter build apk --release

build-ios:
	flutter build ios --release

# Clean
clean:
	flutter clean
	rm -rf coverage/
