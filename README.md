# Softbox

A macOS app that shows a bright white window to light up your face on video calls.

Click the light area to reveal the controls.

## Features

- Brightness and color temperature sliders (2700 K – 6500 K)
- Float on Top / Pin to Back (checkboxes in the panel; also in the View menu)
- Multiple windows — open with ⌘N; each with independent sliders or all linked

## Build

Open `Softbox.xcodeproj` in Xcode, select the `Softbox` scheme, and build/run.

Requires macOS 14 or later.

## Regenerate App Icon

Run this from the repository root:

```sh
python3 generate_icons.py
```

This regenerates the PNG files in `Softbox/Assets.xcassets/AppIcon.appiconset`.
