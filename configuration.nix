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

      # blacklistedKernelModules = [
      #   "nouveau"
      #   "rivafb"
      #   "nvidiafb"
      #   "rivatv"
      #   "nv"
      #   "uvcvideo"
      # ];

      # extraModprobeConfig = ''
      #   options bbswitch load_state=-1 unload_state=1 nvidia-drm
      # '';

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
        killall
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
      support32Bit = true;
      package = pkgs.pulseaudioFull;
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

    hardware.nvidiaOptimus.disable = true;
    hardware.opengl = {
      extraPackages = [ pkgs.linuxPackages.nvidia_x11.out ];
      extraPackages32 = [ pkgs.linuxPackages.nvidia_x11.lib32 ];
      driSupport32Bit = true;
    };

    # hardware.bumblebee = {
    #   enable = true;
    #   group = "video";
    #   connectDisplay = true;
    #   pmMethod = "none";
    # };

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

      displayManager.slim = {
        enable = true;
        autoLogin = true;
        defaultUser = "thomas";
      };

      # desktopManager.xfce.enable = true;

      windowManager.exwm = {
        enable = true;
      };
      windowManager.default = "exwm";

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
    '';


    # systemd.user.services.kb = {
    #   enable = false;
    #   description = "keyboard: layout tweaks and xcape";
    #   wantedBy = [ "graphical.target" "default.target" ];
    #   preStart = ''
    #     ${pkgs.xorg.xkbcomp}/bin/xkbcomp ${compiledLayout} $DISPLAY
    #   '';
    #   restartIfChanged = true;
    #   serviceConfig = {
    #     Type = "forking";
    #     Restart = "always";
    #     RestartSec = 2;
    #     ExecStart = "${pkgs.xcape}/bin/xcape -t 250 -e \'Shift_L=dollar;Shift_R=numbersign;Control_L=Escape;Control_R=Return\'";
    #   };
    # };

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
