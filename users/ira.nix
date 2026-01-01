# User configuration for ira
{ config, pkgs, lib, hostname, ... }:

{
  imports = [
    ../modules/home
  ];

  # Any user-specific overrides can go here
  # The bulk of configuration is in modules/home/*
}
