# App Icon Assets

Place the following files in this directory before running `dart run flutter_launcher_icons`:

| File | Size | Purpose |
|------|------|---------|
| `app_icon.png` | 1024×1024 px | Full icon (used for all legacy Android sizes) |
| `app_icon_fg.png` | 1024×1024 px | Adaptive icon foreground (transparent bg, shield/logo centred in safe zone) |

## Design guidelines
- Background colour: `#0D0D1A` (already configured in pubspec.yaml)
- Foreground: SafeShell shield logo, white/cyan gradient, centred within the inner 66% safe zone
- No padding needed on `app_icon.png` — flutter_launcher_icons handles resizing

## Generate icons
```bash
flutter pub get
dart run flutter_launcher_icons
```
