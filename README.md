# CloneTray

A macOS menu bar application that automatically clones Git repositories and opens up in IDE

## Installation

1. Clone the repo
2. Open Terminal and navigate to the extracted directory
3. Make the launch script executable:

   ```bash
   chmod +x launchd.sh
   ```

4. To start the application:

   ```bash
   ./launchd.sh start
   ```

5. To stop the application:

   ```bash
   ./launchd.sh stop
   ```

## Configuration

CloneTray can be configured via the `config.yml` file:

```yaml
default_clone_base_dir: ~/Developer
ide_app_name: Cursor # Visual Studio Code
default_browser:      # leave empty to auto-detect the active browser
```

You can also change the default IDE and default browser at runtime from the
tray menu under **Settings → Default IDE** and **Settings → Default Browser**.
Changes are persisted back to `config.yml`.
