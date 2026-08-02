-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  -- xdg-desktop-portal-hyprland loses a race at login: systemd starts it before
  -- Hyprland has exported WAYLAND_DISPLAY, so it dies with "Couldn't connect to
  -- a wayland compositor", burns through its restart limit, and stays dead for
  -- the whole session. That silently kills the ScreenCast portal, which is what
  -- OBS screen/window capture (and every other PipeWire capture) depends on.
  -- Import the environment first, then bring the backend up and let the
  -- frontend re-scan it. Chained in one command because exec_cmd calls race.
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE"
    .. " ; systemctl --user reset-failed xdg-desktop-portal-hyprland.service"
    .. " ; systemctl --user restart xdg-desktop-portal-hyprland.service"
    .. " ; systemctl --user restart xdg-desktop-portal.service")

  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("qs")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 30")

end)
