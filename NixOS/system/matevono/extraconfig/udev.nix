{
  config,
  lib,
  pkgs,
  ...
}: {
  services.udev.extraRules = ''


    # original RTL2832U vid/pid (hama nano, for example)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2832", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # RTL2832U OEM vid/pid, e.g. ezcap EzTV668 (E4000), Newsky TV28T (E4000/R820T) etc.
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # DigitalNow Quad DVB-T PCI-E card (4x FC0012?)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0413", ATTRS{idProduct}=="6680", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Leadtek WinFast DTV Dongle mini D (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0413", ATTRS{idProduct}=="6f0f", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Genius TVGo DVB-T03 USB dongle (Ver. B)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0458", ATTRS{idProduct}=="707f", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec Cinergy T Stick Black (rev 1) (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00a9", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec NOXON rev 1 (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b3", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec Deutschlandradio DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b4", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec NOXON DAB Stick - Radio Energy (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b5", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec Media Broadcast DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b7", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec BR DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b8", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec WDR DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00b9", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec MuellerVerlag DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00c0", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec Fraunhofer DAB Stick (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00c6", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec Cinergy T Stick RC (Rev.3) (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00d3", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec T Stick PLUS (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00d7", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Terratec NOXON rev 2 (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0ccd", ATTRS{idProduct}=="00e0", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # PixelView PV-DT235U(RN) (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1554", ATTRS{idProduct}=="5020", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Astrometa DVB-T/DVB-T2 (R828D)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="15f4", ATTRS{idProduct}=="0131", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # HanfTek DAB+FM+DVB-T
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="15f4", ATTRS{idProduct}=="0133", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Compro Videomate U620F (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="185b", ATTRS{idProduct}=="0620", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Compro Videomate U650F (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="185b", ATTRS{idProduct}=="0650", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Compro Videomate U680F (E4000)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="185b", ATTRS{idProduct}=="0680", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # GIGABYTE GT-U7300 (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d393", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # DIKOM USB-DVBT HD
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d394", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Peak 102569AGPK (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d395", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # KWorld KW-UB450-T USB DVB-T Pico TV (TUA9001)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d397", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Zaapa ZT-MINDVBZP (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d398", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # SVEON STV20 DVB-T USB & FM (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d39d", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Twintech UT-40 (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d3a4", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # ASUS U3100MINI_PLUS_V2 (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d3a8", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # SVEON STV27 DVB-T USB & FM (FC0013)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d3af", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # SVEON STV21 DVB-T USB & FM
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b80", ATTRS{idProduct}=="d3b0", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Dexatek DK DVB-T Dongle (Logilink VG0002A) (FC2580)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1d19", ATTRS{idProduct}=="1101", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Dexatek DK DVB-T Dongle (MSI DigiVox mini II V3.0)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1d19", ATTRS{idProduct}=="1102", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Dexatek DK 5217 DVB-T Dongle (FC2580)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1d19", ATTRS{idProduct}=="1103", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # MSI DigiVox Micro HD (FC2580)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1d19", ATTRS{idProduct}=="1104", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Sweex DVB-T USB (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1f4d", ATTRS{idProduct}=="a803", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # GTek T803 (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1f4d", ATTRS{idProduct}=="b803", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # Lifeview LV5TDeluxe (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1f4d", ATTRS{idProduct}=="c803", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # MyGica TD312 (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1f4d", ATTRS{idProduct}=="d286", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

    # PROlectrix DV107669 (FC0012)
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1f4d", ATTRS{idProduct}=="d803", ENV{ID_SOFTWARE_RADIO}="1", MODE="0660", GROUP="plugdev"

  '';
}
