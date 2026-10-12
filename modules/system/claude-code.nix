# Claude Code — organization-managed policy (box-wide, all users).
#
# This managed-settings.json carries five things: the cross-session peer-tool
# deny (below), the telemetry env, the channel-notifications opt-in, the
# transcript retention period and the commit/PR attribution switch-off (all at
# the builder near the bottom). All are declarative + root-owned so they cannot
# be weakened by a dotfile, and ride to every host in this flake.
#
# Denies the cross-session peer tools ListAgents and SendMessage. As of
# CC >= 2.1.224 any session can enumerate and inject text into another
# session addressed by name; RECEIVING is not a tool call, so it cannot be
# gated on the receiver — the only durable control is to deny the SENDER's
# tools everywhere. the orchestrator runs all its own orchestration channels and needs
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
# re-verify tool names on upgrade. the orchestrator asserts this deny is in effect at
# bringup; it does not write this file (single-author avoids the observed
# concurrent-write corruption of shared CC settings files).
{ config, pkgs, lib, hostname, ... }:

{
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    permissions = {
      deny = [ "ListAgents" "SendMessage" ];
    };

    # Telemetry, declarative. KEEP survey + error-reporting suppression; do NOT
    # set DISABLE_TELEMETRY — despite the name it is not a telemetry switch: it
    # kills the whole GrowthBook feature-flag client, so ~132 flags fall to
    # compiled defaults that disagree with the account's cached values. On this
    # box it broke inbound MCP channel notifications (2026-08-22) and breaks
    # Remote Control (presents as available, then never connects, because RC's
    # gate is on the async flag path). CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY alone
    # blocks all eight survey call sites, which is all that was actually wanted.
    # Removing DISABLE_TELEMETRY only resumes first-party analytics, which on
    # this box is near-nothing (head_sha is the sole repo-identifying field and
    # it is stale — nested repos leave the workspace HEAD unchanged).
    env = {
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      DISABLE_ERROR_REPORTING = "1";
    };

    # Managed-org opt-in for inbound channel notifications. On team/enterprise
    # plans CC turns channels OFF unless this is true — verified in 2.1.231:
    # (plan==="team"||plan==="enterprise") && channelsEnabled!==true => off.
    # A director on a Team plan would otherwise come up with NO job
    # notifications and look like the orchestrator is broken. Harmless on individual
    # (max/pro) plans, which never consult it, so it is safe to set now ahead of
    # work moving to Team. (That same team/enterprise branch also stops CC
    # sending head_sha at all — the good half.)
    channelsEnabled = true;

    # Keep session transcripts ~10 years: they are each session's memory and
    # the record ccusage tallies cost from, and deletion is irreversible. 3650
    # is CC's own "long retention" example; 0 is invalid (minimum 1).
    # LOWERING THIS DELETES: at the next CC start, every transcript older than
    # the new value is removed, on every host this file reaches. Archive
    # ~/.claude/projects first, then lower. The same age also governs CC's
    # other sweeps (file-history, plans, paste-cache, tool-results).
    cleanupPeriodDays = 3650;

    # No attribution in commits or PRs: no Co-Authored-By trailer, no
    # "Generated with" line, and no Claude-Session trailer, which would publish
    # a session URL in every pushed commit. Object form: some CC versions reject
    # a boolean here and then skip the whole file.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
