# Screenshots

To regenerate the README screenshots:

1. Build and launch the app:
   ```bash
   make run
   ```

2. Capture the menu bar region interactively (drag a selection across the LudeVitals icons):
   ```bash
   screencapture -i docs/menubar.png
   ```

3. Open the popover (click the menu bar icon), then capture it:
   ```bash
   screencapture -i docs/popover.png
   ```

Both shots should be PNG at native retina resolution. Trim transparent margins after capture if needed.
