# Claude Code — organization-managed policy (box-wide, all users).
#
# Denies the cross-session peer tools ListAgents and SendMessage. As of
# CC >= 2.1.224 any session can enumerate and inject text into another
# session addressed by name; RECEIVING is not a tool call, so it cannot be
# gated on the receiver — the only durable control is to deny the SENDER's
# tools everywhere. dario runs all its own orchestration channels and needs
# nothing from CC's native peer messaging, so on our boxes this channel is
# pure liability (it would let one context inject into another and defeat
# deliberate clean-room / licensing separation).
#
# Why the MANAGED tier (/etc/claude-code/managed-settings.json), not
# ~/.claude/settings.json:
#   - Root-owned and rebuild-only. claude-yolo bind-mounts $HOME/.claude
#     read-write, so a deny in the dotfile could be edited by a bypass
#     session; a managed rule cannot be weakened by user/project/local/CLI
#     rules and only changes on a rebuild.
#   - Applies to every session of every user on the box, and rides to every
#     host in this flake (incl. the work laptop) with no dotfile to copy.
#
# Verified against the shipped binary (2.1.231): the managed path and these
# tool names exist, and a bare tool name parses as a whole-tool deny
# (parser: no "(" => the whole string is the tool name). Deny outranks allow
# and managed outranks user, so allowManagedPermissionRulesOnly is NOT set —
# that flag would also void the user allow-list (git worktree/remote, etc.)
# for zero added protection on a deny.
#
# DURABILITY: this control is keyed on TOOL NAMES and client-side. A CC
# release that renames these tools, adds a third peer tool, or bumps the
# session peerProtocol reopens the hole silently. Pin moved 2.1.226 ->
# 2.1.231 within a day, unplanned. Treat CC version bumps as a canary and
# re-verify tool names on upgrade. dario asserts this deny is in effect at
# bringup; it does not write this file (single-author avoids the observed
# concurrent-write corruption of shared CC settings files).
{ config, pkgs, lib, hostname, ... }:

{
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    permissions = {
      deny = [ "ListAgents" "SendMessage" ];
    };
  };
}
