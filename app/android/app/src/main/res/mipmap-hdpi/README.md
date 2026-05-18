# App Icons

Prompt Gladiators ships without pre-generated launcher icons.

## Generating icons

Use `flutter_launcher_icons` to generate all densities from a single source image:

1. Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1

   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/images/icon.png"  # 1024x1024 recommended
     adaptive_icon_background: "#0A0A0F"   # ArenaTheme.background
     adaptive_icon_foreground: "assets/images/icon_fg.png"
   ```

2. Run:
   ```bash
   dart run flutter_launcher_icons
   ```

This replaces the `mipmap-*/ic_launcher.png` files in all density buckets.

## Placeholder

Until real icons are generated, Flutter uses its default icon. The app
builds and runs correctly — it just shows the Flutter logo on the home screen.

## Design suggestion

- Dark background (`#0A0A0F`)
- Two opposing arcs in red (`#FF3C3C`) and blue (`#3C8EFF`) forming a yin-yang
- White or accent-red crossed swords or `PG` monogram in centre
