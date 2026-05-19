{
  config,
  lib,
  pkgs,
  ...
}: {
  hardware = {
    firmware = [
      pkgs.sof-firmware
      (
        pkgs.runCommand "customedid.bin" {compressFirmware = false;} ''
           mkdir -p $out/lib/firmware/edid
          cp "${../firmware/customedid.bin}" $out/lib/firmware/edid/customedid.bin
        ''
      )
    ];
  };

  systemd = {
    # Workaround: Sometimes xhci driver will become malfunctional after resuming from hibernate / suspend.
    #             This will cause (almost) all external devices stop working.
    #             A simple reset is enough to bring external devices alive :)
    #
    #             Note: to avoid unnecessary resets, we firstly check if integrated camera is presented
    #                   (Should always be there as it was built into machine!).
    #                   If not, just do the reset.
    services.workaround-reset-xhci-driver-after-resume-if-needed = {
      script = ''
        result=$(${pkgs.usbutils}/bin/lsusb | ${pkgs.gnugrep}/bin/grep Luxvisions || true)
        if [[ -z $result ]]; then
          ${pkgs.kmod}/bin/rmmod xhci_pci xhci_hcd
          ${pkgs.kmod}/bin/modprobe xhci_pci xhci_hcd
        fi
      '';
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
      ];
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "multi-user.target"
      ];
    };

    # Workaround: Lenovo seems write bad acpi power management firmware. Without this config,
    #             suspend (to ram / disk) will simply reboot instead of power off. :(
    sleep.settings = {
      Sleep = {
        HibernateMode = "shutdown";
      };
    };
  };
}
