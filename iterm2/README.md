# iTerm2 Scripts

AutoLaunch scripts using the iTerm2 Python API.

## Setup

```sh
mkdir -p ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch
ln -s ~/ghq/github.com/nkmr-jp/setup/iterm2/PaneCount.py ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/PaneCount.py
```

The scripts run automatically after restarting iTerm2.

## PaneCount.py

Set the current tab's pane count in the user-defined variable `user.paneCount`.
`LayoutChangeMonitor` watches pane additions and removals in real time and updates it automatically.

### Display configuration

In Preferences → Profiles → General → Title:

1. Select the desired items in the Title dropdown.
2. Enter a custom string in the text field below checkboxes such as "Session Name".

Example:

```
\(user.paneCount) panes
```

`user.paneCount` is set as a user-defined iTerm2 variable for each session. Besides
tab titles, it is available anywhere that accepts `\(user.paneCount)`, including
the Status Bar and triggers.
