{ config, pkgs, ... }:

let
  # keyboard
  compiledLayout = pkgs.runCommand "keyboard-layout" {} ''
    ${pkgs.xorg.xkbcomp}/bin/xkbcomp ${/etc/nixos/layout.xkb} $out
  '';

in
{
    imports =
      [ # Include the results of the hardware scan.
        ./hardware-configuration.nix
      ];

    # Use the systemd-boot EFI boot loader.
    boot = {
      loader.systemd-boot.enable = true;
      loader.efi.canTouchEfiVariables = true;
      kernelParams = ["acpi_rev_override" "mem_sleep_default=deep" "intel_iommu=igfx_off" ];
      # kernelPackages = pkgs.linuxPackages_latest;
      extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

      blacklistedKernelModules = [
        "nouveau"
        "rivafb"
        "nvidiafb"
        "rivatv"
        "nv"
        "uvcvideo"
      ];

      extraModprobeConfig = ''
        # handle NVIDIA optimus power management quirk
        options bbswitch load_state=-1 unload_state=1 nvidia-drm
      '';

      tmpOnTmpfs = true;

    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };


    system.autoUpgrade.enable = true;

    networking.networkmanager.enable = true;

    # Select internationalisation properties.
    i18n = {
      consoleFont = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
      consoleUseXkbConfig = true;
      defaultLocale = "en_US.UTF-8";
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
        ultimate.enable = true;
        defaultFonts = {
          monospace = ["DejaVu Sans Mono" "IPAGothic"];
          sansSerif = ["DejaVu Sans" "IPAPGothic"];
          serif = ["DejaVu Serif" "IPAPMincho"];
        };
      };
    };

  # Set your time zone.
    time.timeZone = "Europe/Oslo";

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    nixpkgs.config.allowUnfree = true;
    environment = {
      systemPackages = with pkgs; [
        acpi
        any-nix-shell
        arandr
        autorandr
        bind
        curl
        emacs
        exfat
        exfat-utils
        fd
        fish
        git
        ispell
        libinput
        libinput-gestures
        networkmanager
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
    };

    # Enable sound.
    sound.enable = true;
    hardware.pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
      support32Bit = true;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      # optimus_prime = {
        #   enable = true;
      #   nvidiaBusId = "PCI:1:0:0";
      #   intelBusId = "PCI:0:2:0";
      # };
    };

    programs = {
      fish = {
        enable = true;
        promptInit = ''
          any-nix-shell fish --info-right | source
        '';
      };
      ssh.startAgent = true;
    };

    # hardware.bumblebee = { enable = true; pmMethod = "none"; };
    hardware.bumblebee = { enable = true; group = "video"; connectDisplay = true; pmMethod = "none"; };

    hardware.nvidiaOptimus.disable = true;
    hardware.opengl.extraPackages = [ pkgs.linuxPackages.nvidia_x11.out ];
    hardware.opengl.extraPackages32 = [ pkgs.linuxPackages.nvidia_x11.lib32 ];
    # hardware.opengl.driSupport32Bit = true;

    services.xserver = {
      enable = true;
      libinput = {
        enable = true;
        naturalScrolling = true;
        disableWhileTyping = true;
      };
      # xkbVariant = "dvp";
      # xkbOptions = "ctrl:nocaps";
      exportConfiguration = true;
      autoRepeatDelay = 250;
      autoRepeatInterval = 150;

      displayManager.slim = {
        enable = true;
        autoLogin = true;
        defaultUser = "thomas";
      };


      desktopManager.xfce.enable = true;

      # videoDrivers = [ "nvidiaBeta" ];
      # videoDrivers = [ "intel" ];
      # videoDrivers = [ "nouveau" ];
      # videoDrivers = [ "modesetting" ];
      # videoDrivers = [ "nvidia" ];
      # videoDrivers = [ "nvidia" "intel" ];

      # windowManager.exwm = {
      #   enable = true;
      #   enableDefaultConfig = false;
      # };
      # windowManager.default = "exwm";

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
        "wheel" "disk" "audio" "video" "networkmanager" "systemd-journal" "docker"
      ];
    createHome = true;
    uid = 1000;
    home = "/home/thomas";
    shell = pkgs.fish;
    };

    services.emacs.enable = true;
    services.emacs.defaultEditor = true;

    services.offlineimap = {
      enable = true;
      install = true;
    };

    services.nixosManual.showManual = true;

    virtualisation.docker = {
      enable = false;
      autoPrune = {
        enable = true;
        flags = ["--all"];
      };
    };


    systemd.user.services.kb = {
      enable = true;
      description = "keyboard: layout tweaks and xcape";
      wantedBy = [ "graphical.target" "default.target" ];
      preStart = ''
        ${pkgs.xorg.xkbcomp}/bin/xkbcomp ${compiledLayout} $DISPLAY
      '';
      restartIfChanged = true;
      serviceConfig = {
        Type = "forking";
        Restart = "always";
        RestartSec = 2;
        ExecStart = "${pkgs.xcape}/bin/xcape -t 250 -e \'Shift_L=dollar;Shift_R=numbersign;Control_L=Escape;Control_R=Return\'";
      };
    };
}

#  LocalWords:  thomas dvp LocalWords
