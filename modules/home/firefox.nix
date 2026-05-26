# Firefox — OLED-friendly defaults via user.js prefs
{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-bin;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        # Force dark mode for UI and content where possible
        "ui.systemUsesDarkTheme" = 1;
        "layout.css.prefers-color-scheme.content-override" = 0;  # 0 = dark
        "browser.theme.toolbar-theme" = 0;                       # 0 = dark
        "browser.theme.content-theme" = 0;

        # Compact density (less chrome height = fewer always-on pixels)
        "browser.uidensity" = 1;  # 1 = compact

        # Hide bookmarks toolbar by default (still toggleable with Ctrl+Shift+B)
        "browser.toolbars.bookmarks.visibility" = "never";

        # Disable Pocket / suggestions / sponsored shortcuts (less static chrome on new tab)
        "extensions.pocket.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      };

      # userChrome.css for things prefs can't cover
      userChrome = ''
        /* Slightly dim the URL bar text so the always-on address isn't peak-white */
        #urlbar, #urlbar-input {
          color: #dddddd !important;
        }
      '';
    };
  };
}
