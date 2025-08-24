# ShowOnDesktopTemp
Temporarily “show” the contents of a chosen folder on your Desktop without copying anything.
What this script does (short description)
Purpose: Temporarily “show” the contents of a chosen folder on your Desktop without copying anything.
How: It creates symlinks (shortcuts) on the Desktop to the selected folder’s immediate children and records exactly which links it made.
Use: In Nautilus, right-click a folder → Scripts → show_on_desktop_temp.
First run: creates the temporary view on your Desktop.
Next runs: offers to Clear the current view or Replace it with another folder.
Safety: It never deletes real files. On clear, it removes only the links it created (tracked in a hidden manifest). Existing Desktop items are left untouched; name collisions are skipped.
Notes: Press F5 on the Desktop if icons don’t update immediately. The script also works with localized Desktops (uses xdg-user-dir DESKTOP) and refuses to “show” the Desktop itself.

Works so far on Ubuntu 24/25. with Nautilus. Later on ChatGPT 5.0 promissed: we can add support for remote/GVFS paths (using NAUTILUS_SCRIPT_SELECTED_URIS + gio). The procedure is to place the script in ~/.local/share/nautilus/scripts/ and enable it with chmod +x. 
