import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Text {
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string rawTitle: toplevel ? toplevel.title : ""

    text: {
        if (!toplevel) return "";
        const firefox = rawTitle.match(/^(.*) - Mozilla Firefox$/);
        if (firefox) return "🌎 " + firefox[1];
        const zsh = rawTitle.match(/^(.*) - zsh$/);
        if (zsh) return "> [" + zsh[1] + "]";
        return "( " + rawTitle + " )";
    }

    readonly property bool hasArabic: /[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]/.test(rawTitle)

    color: Colors.text
    font.family: hasArabic ? "Noto Sans Arabic" : "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    elide: Text.ElideRight
    Layout.maximumWidth: 380
}
