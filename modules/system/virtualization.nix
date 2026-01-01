# Virtualization configuration (Podman, libvirt, Vagrant)
{ config, pkgs, lib, ... }:

{
  # Podman (Docker-compatible)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # libvirt/KVM
  virtualisation.libvirtd.enable = true;

  # Vagrant (uses libvirt provider)
  environment.systemPackages = with pkgs; [
    vagrant
  ];
}
