# ShowOnDesktopTemp
Temporarily “show” the contents of a chosen folder or file/s on your desktop without copying anything. How: It creates symlinks (shortcuts) on the desktop to the selected folder’s immediate children and records exactly which links it made. Use: In Nautilus, right-click a folder → Scripts → show_on_desktop_temp. First run: creates the temporary view on your desktop. Next run: offers to clear the current view or replace it with another folder. Safety: It never deletes real files. On clear, it removes only the links it created (tracked in a hidden manifest). Existing desktop items are left untouched; name collisions are skipped. Notes: Press F5 on the desktop if icons don’t update immediately. The script also works with localized desktops (uses xdg-user-dir DESKTOP) and refuses to “show” the desktop itself.

Works so far on Ubuntu's latest LTSes with Nautilus. The procedure is to place the script in ~/.local/share/nautilus/scripts/ and enable it with chmod +x. It needs to have a shell extension showing the desktop icons, like the Desktop Icons NG (DING) extension.

## License

This project is **dual-licensed**: **Apache-2.0 OR CC0-1.0** (your choice).

- If you choose **Apache-2.0**:
  - Include **LICENSE.Apache-2.0** and **NOTICE** when redistributing.
  - Preserve copyright and license headers in source form.
  - Clearly mark **modifications** to files.
  - Includes a patent grant and standard disclaimers.

- If you choose **CC0-1.0**:
  - Public-domain-like dedication; no attribution or notice required.
  - Trademark and patent rights are **not** granted by CC0.

SPDX header (recommended) at the top of each source file:

# SPDX-License-Identifier: Apache-2.0 OR CC0-1.0
# Copyright (c) 2025 Harald Wenzel

# ShowOnDesktopTemp De
Zeigt vorübergehend den Inhalt eines ausgewählten Ordners oder einer Datei auf deinem Desktop an, ohne etwas zu kopieren. Wie? Es erstellt Symlinks (Verknüpfungen) auf dem Desktop zu den unmittelbaren Unterordnern un Dateien des ausgewählten Ordners und zeichnet genau auf, welche Verknüpfungen es erstellt hat. Verwendung: Klicke in Nautilus mit der rechten Maustaste auf einen Ordner → Skripte → show_on_desktop_temp. Erster Durchlauf: erstellt die temporäre Ansicht auf deinem Desktop. Nächster Durchlauf: bietet an, die aktuelle Ansicht zu löschen oder sie durch einen anderen Ordner zu ersetzen. Sicherheit: Es werden keine echten Dateien gelöscht. Beim Löschen werden nur die erstellten Verknüpfungen entfernt (die in einem versteckten Manifest gespeichert werden). Vorhandene Desktop-Elemente bleiben unberührt; Namenskollisionen werden übersprungen. Hinweise: Drücke F5 auf dem Desktop, wenn die Symbole nicht sofort aktualisiert werden. Das Skript funktioniert auch mit lokalisierten Desktops (verwendet xdg-user-dir DESKTOP) und weigert sich, den Desktop selbst „anzuzeigen“.

Bisher funktioniert es auf den neuesten LTS von Ubuntu mit Nautilus. Das Verfahren besteht darin, das Skript in ~/.local/share/nautilus/scripts/ abzulegen und es mit chmod +x zu machen. Es muss eine Shell-Erweiterung haben, die die Desktop-Symbole anzeigt, wie die Desktop Icons NG (DING) Erweiterung.
