{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xserver.windowManager.myExwm;
  loadScript = pkgs.writeText "emacs-exwm-load" ''
    ${cfg.loadScript}
    ${optionalString cfg.enableDefaultConfig ''
      (require 'exwm-config)
      (exwm-config-default)
    ''}
  '';
  exwm-emacs = cfg.executable;

in {
  options = {
    services.xserver.windowManager.myExwm = {
      enable = mkEnableOption "exwm";
      loadScript = mkOption {
        default = "(require 'exwm)";
        example = literalExample ''
          (require 'exwm)
          (exwm-enable)
        '';
        description = ''
          Emacs lisp code to be run after loading the user's init
          file. If enableDefaultConfig is true, this will be run
          before loading the default config.
        '';
      };
      enableDefaultConfig = mkOption {
        default = true;
        type = lib.types.bool;
        description = "Enable an uncustomised exwm configuration.";
      };
      executable = mkOption {
        default = pkgs.emacsWithPackages (epkgs: [ epkgs.exwm ]);
        example = literalExample ''
          emacsWithPackagesFromUsePackage {
                config = ./init.el;
                package = pkgs.emacsGit;
          };
        '';
        description = ''
          Which emacs executable to use, including packages.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.xserver.windowManager.session = singleton {
      name = "exwm";
      start = ''
        ${exwm-emacs}/bin/emacs -l ${loadScript}
      '';
    };
    environment.systemPackages = [ exwm-emacs ];
  };
}
