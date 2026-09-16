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

  # Drop the two ssh-proxy Includes NixOS adds to the system /etc/ssh/ssh_config.
  # Both fragments are root-owned in the nix store; a director runs ssh inside a
  # `systemd --user` sandbox whose user namespace maps root -> nobody(65534), so
  # OpenSSH's strict-modes check rejects them as "Bad owner or permissions" and
  # refuses to connect at all — surfacing as git's misleading "check your access
  # rights". Neither proxy is used here (local KVM/virt-manager/vagrant go over
  # the local socket; we don't ssh to remote libvirt or systemd machines), so
  # turning them off removes the tripwire at the source for every director.
  #   sshProxy            -> 30-libvirt-ssh-proxy.conf (qemu+ssh:// remote libvirt)
  #   systemd-ssh-proxy   -> 20-systemd-ssh-proxy.conf (ssh unix//vsock//.host)
  virtualisation.libvirtd.sshProxy = false;
  programs.ssh.systemd-ssh-proxy.enable = false;

  # Vagrant (uses libvirt provider)
  environment.systemPackages = with pkgs; [
    vagrant
  ];
}
