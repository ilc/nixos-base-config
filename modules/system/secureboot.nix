# Secure Boot via lanzaboote, with our own keys (hosts in secureBootHosts).
#
# Integrity only: the firmware refuses unsigned boot code, closing the
# unencrypted-ESP "evil maid" path. Authentication stays with the LUKS
# passphrase — the TPM never releases the disk key.
#
# Keys live in /var/lib/sbctl (root-only, on the encrypted root), created once
# per machine with `sbctl create-keys`; they never enter the nix store or git.
# Enrollment is manual (auto-enroll off: its default also trusts Microsoft).
# Recovery: BIOS → "Reset Secure Boot keys to factory defaults".
{ config, lib, pkgs, inputs, isSecureBoot, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  config = lib.mkIf isSecureBoot {
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    environment.systemPackages = [ pkgs.sbctl ];
  };
}
