# Porch

A simple Windows app for viewing the house's RTSP cameras and controlling Home Assistant devices. Built with Flutter, developed on macOS.

## Develop (macOS)

```sh
flutter pub get
flutter run -d macos
flutter analyze && flutter test
```

The first time the Mac build opens, macOS asks to let Porch find devices on your local network. Allow it, or cameras and Home Assistant on your LAN stay unreachable.

### Without a real Home Assistant

`tool/fake_ha.dart` runs a stand-in Home Assistant with a sample house (lights, a thermostat, a lock, a garage door, scenes). The tests use it too.

```sh
dart run tool/fake_ha.dart
```

Then in Porch's Settings use `http://127.0.0.1:8123` and the token `dev`.

## How it talks to Home Assistant

Porch uses the Home Assistant WebSocket API with a long-lived access token: it loads states plus the area, device and entity registries (for room names), subscribes to `state_changed` for live updates, and sends `call_service` for controls. It reconnects on its own when the connection drops.

## Windows builds

Flutter can't build Windows apps from macOS, so GitHub Actions does it (`.github/workflows/build.yml`):

- Every push to `main` builds `PorchSetup-<version>.exe` and a zip, available as the `Porch-windows-x64` workflow artifact.
- Pushing a `v*` tag publishes them as a GitHub release.

media_kit's build downloads two prebuilt archives from GitHub release links that often answer 504, so the workflow fetches them through the GitHub API first.

### Releasing and updates

Set `version:` in `pubspec.yaml`, commit, push, then push the matching tag (the workflow fails if they differ):

```sh
git tag v0.2.0 && git push origin v0.2.0
```

Porch checks this repo's latest release when it opens and every 12 hours. A newer version shows an "Update available" card in the sidebar and in Settings > Updates. On Windows, Install downloads the installer, runs it silently, and Porch reopens on the new version. The installer is per-user, so it never asks for admin. The Mac build only links to the release.

The first install on a PC is by hand: run `PorchSetup-<version>.exe` from the release.

## Secrets

This repo is public. Home Assistant tokens and camera URLs (which often include passwords) are entered in the app and stored on the device, never committed. They live as plain JSON (`settings.json`, `cameras.json`) in the app's support folder.

## Icon

`assets/icon/porch.svg` is the master. To regenerate the Windows `.ico` and macOS app icons:

```sh
uv run --with pillow tool/make_icons.py
```
