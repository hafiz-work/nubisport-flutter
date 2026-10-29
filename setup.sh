#!/usr/bin/env bash
# Clean setup: clean -> pub get -> pod install (macOS/iOS only) -> build_runner.
# Ask everything first, then run without stopping again.
set -euo pipefail
cd "$(dirname "$0")"

app_slug=nubi-sport # base name, no "Dev" suffix - $flavor already says that
do_build=false
target=apk
flavor=prod

read -r -p "Build apk/aab after setup? [y/N] " answer
case "${answer:-n}" in [yY]*) do_build=true ;; esac
if $do_build; then
  read -r -p "Format (apk/aab) [apk] " answer
  target="${answer:-apk}"
  case "$target" in
    apk) task=apk ;;
    aab) task=appbundle ;;
    *) echo "Unknown format: $target" >&2; exit 1 ;;
  esac
  read -r -p "Flavor (dev/prod) [prod] " answer
  flavor="${answer:-prod}"

  version=$(sed -n 's/^version: *//p' pubspec.yaml) # 1.0.0+1
  name="$app_slug-v${version%%+*}(${version##*+})-$flavor.$target"
  case "$target" in
    apk) src="build/app/outputs/flutter-apk/app-$flavor-release.apk" ;;
    aab) src="build/app/outputs/bundle/${flavor}Release/app-$flavor-release.aab" ;;
  esac
fi

plan=("flutter clean" "flutter pub get")
if [[ "$(uname)" == Darwin && -f ios/Podfile ]]; then
  plan+=("(cd ios && pod install)")
fi
plan+=("dart run build_runner build")
if $do_build; then
  plan+=("flutter build $task --flavor $flavor")
  plan+=("cp $src -> $target/$name")
fi

echo
printf '==> %s\n' "${plan[@]}"
echo

flutter clean
flutter pub get
if [[ "$(uname)" == Darwin && -f ios/Podfile ]]; then
  (cd ios && pod install)
fi
dart run build_runner build
if $do_build; then
  flutter build "$task" --flavor "$flavor"
  [[ -f "$src" ]] || { echo "Build output not found: $src" >&2; exit 1; }
  mkdir -p "$target"
  cp "$src" "$target/$name"
  echo "==> $target/$name"
fi

echo "Done."
