# Audio configuration (PipeWire)
{ config, pkgs, lib, ... }:

{
  # Disable PulseAudio
  services.pulseaudio.enable = false;

  # PipeWire
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };
}
