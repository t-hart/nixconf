{ config, pkgs, ... }:

let
  # keyboard
  compiledLayout = pkgs.runCommand "keyboard-layout" {} ''
    ${pkgs.xorg.xkbcomp}/bin/xkbcomp ${/etc/nixos/layout.xkb} $out
  '';

  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';


in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = [
      "acpi_rev_override"
      "mem_sleep_default=deep"
      "intel_iommu=igfx_off"
      # PCI-Express Runtime D3 (RTD3) Power Management
      # https://download.nvidia.com/XFree86/Linux-x86_64/450.51/README/dynamicpowermanagement.html
      "nvidia.NVreg_DynamicPowerManagement=0x02"
      # If the Spectre V2 mitigation is necessary, some performance may be recovered by setting the
      # NVreg_CheckPCIConfigSpace kernel module parameter to 0. This will disable the NVIDIA driver's
      # sanity checks of GPU PCI config space at various entry points, which were originally required
      # to detect and correct config space manipulation done by X server versions prior to 1.7.
      "nvidia.NVreg_CheckPCIConfigSpace=0"
      # Enable the PAT feature [5], which affects how memory is allocated. PAT was first introduced in
      # Pentium III [6] and is supported by most newer CPUs (see wikipedia:Page attribute table#Processors).
      # If your system can support this feature, it should improve performance.
      "nvidia.NVreg_UsePageAttributeTable=1"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    blacklistedKernelModules = [
      "nouveau"
      "nvidiafb"

      "nvidia"
      "nvidia-uvm"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    tmpOnTmpfs = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.autoUpgrade.enable = true;

  networking.networkmanager.enable = true;
  networking.firewall = {
    allowedTCPPorts = [ 17500 ];
    allowedUDPPorts = [ 17500 ];
  };

  # Select internationalisation properties.
  i18n = { defaultLocale = "en_US.UTF-8"; };

  console = {
    useXkbConfig = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  };

  fonts = {
    fonts = with pkgs; [
      dejavu_fonts
      fira-code
      fira-code-symbols
      ipafont
      kochi-substitute
      mplus-outline-fonts
      powerline-fonts
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [ "DejaVu Sans Mono" "IPAGothic" ];
        sansSerif = [ "DejaVu Sans" "IPAPGothic" ];
        serif = [ "DejaVu Serif" "IPAPMincho" ];
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (
      import (
        builtins.fetchTarball {
          url =
            "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
        }
      )
    )
  ];

  environment = {
    systemPackages = with pkgs; [
      acpi
      any-nix-shell
      arandr
      autorandr
      bind
      bitwarden-cli
      cacert
      curl
      dropbox-cli
      exfat
      exfat-utils
      fd
      fish
      git
      ispell
      killall
      libinput
      libinput-gestures
      networkmanager
      notmuch
      nvidia-offload
      nvtop
      pciutils
      powertop
      tmux
      unzip
      vim
      thunderbolt
      tree
      wget
      xcape
      xclip
      xorg.xev
      xorg.xkbcomp
      zip
    ];

    interactiveShellInit = ''
      alias nixdot='git --git-dir=/etc/nixos/git --work-tree=/etc/nixos/'
    '';

    variables."SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt";
  };

  # Enable sound.
  sound.enable = true;

  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;
    package = pkgs.pulseaudioFull;
  };

  hardware.bluetooth.enable = true;

  programs = {
    fish = {
      enable = true;
      promptInit = ''
        any-nix-shell fish --info-right | source
      '';
    };
    ssh.startAgent = true;
    tmux = {
      enable = true;
      clock24 = true;
    };
    gnupg = { agent.enable = true; };
  };

  hardware.nvidia = {
    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    modesetting.enable = true;
    nvidiaPersistenced = true;
    powerManagement.enable = true;

  };

  # hardware.opengl.enable = true;

  services.thermald.enable = true;

  location.longitude = 10.45;
  location.latitude = 59.54;

  services.redshift = {
    enable = true;
    brightness.night = "0.8";
    extraOptions = [ "-m randr" ];
  };

  # https://github.com/target/lorri/
  services.lorri.enable = true;

  services.xserver = {
    enable = true;
    libinput = {
      enable = true;
      naturalScrolling = true;
      disableWhileTyping = true;
    };
    exportConfiguration = true;
    autoRepeatDelay = 250;
    autoRepeatInterval = 150;

    videoDrivers = [ "nvidia" ];

    windowManager.exwm = {
      enable = true;
      enableDefaultConfig = false;
      extraPackages = epkgs: [
        epkgs.emacsql-sqlite
        epkgs.vterm
        epkgs.magit
        epkgs.pdf-tools
      ];
    };

    useGlamor = true;

    displayManager.autoLogin.user = "thomas";
    displayManager.defaultSession = "none+exwm";
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?

  # users
  users.extraUsers.thomas = {
    name = "thomas";
    group = "users";
    extraGroups = [
      "audio"
      "disk"
      "docker"
      "networkmanager"
      "systemd-journal"
      "video"
      "wheel"
    ];
    createHome = true;
    uid = 1000;
    home = "/home/thomas";
    shell = pkgs.fish;
  };

  # services.emacs.enable = true;
  services.emacs.defaultEditor = true;

  services.offlineimap = {
    enable = true;
    install = true;
    path = [ pkgs.notmuch pkgs.bitwarden-cli pkgs.fish ];
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };
  };

  services.udev.extraRules = ''
    # Teensy rules for the Ergodox EZ Original / Shine / Glow
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

    # STM32 rules for the Planck EZ Standard / Glow
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", \
        MODE:="0666", \
        SYMLINK+="stm32_dfu"

    # Runtime PM for PCI Device NVIDIA Corporation GP107M [GeForce GTX 1050 Ti Mobile]
    ACTION=="add", SUBSYSTEMS=="pci", ATTRS{device}=="0x1901", ATTRS{vendor}=="0x8086", TEST=="power/control", ATTR{power/control}="auto"
  '';

  # based on https://nixos.wiki/wiki/Dropbox and https://discourse.nixos.org/t/using-dropbox-on-nixos/387/5
  systemd.user.services.dropbox = {
    description = "Dropbox";
    wantedBy = [ "graphical-session.target" ];
    environment = {
      QT_PLUGIN_PATH = "/run/current-system/sw/"
      + pkgs.qt5.qtbase.qtPluginPrefix;
      QML2_IMPORT_PATH = "/run/current-system/sw/"
      + pkgs.qt5.qtbase.qtQmlPrefix;
    };
    serviceConfig = {
      ExecStart = "${pkgs.dropbox.out}/bin/dropbox";
      ExecReload = "${pkgs.coreutils.out}/bin/kill -HUP $MAINPID";
      KillMode = "control-group"; # upstream recommends process
      Restart = "on-failure";
      PrivateTmp = true;
      ProtectSystem = "full";
      Nice = 10;
    };
  };
  security.sudo.extraConfig = ''
    %wheel ALL=(ALL:ALL) ${pkgs.systemd}/bin/poweroff
    %wheel ALL=(ALL:ALL) ${pkgs.systemd}/bin/reboot
    %wheel ALL=(ALL:ALL) ${pkgs.systemd}/bin/systemctl suspend
    %wheel ALL=(ALL:ALL) ${pkgs.systemd}/bin/systemctl hibernate
  '';

  systemd.user.services.autorandrize = {
    enable = true;
    description = "Automatically adjust screens when waking up";
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeOutSec = "0";
      ExecStart = "${pkgs.autorandr}/bin/autorandr -c";
    };
  };
}

#  LocalWords:  thomas dvp LocalWords
