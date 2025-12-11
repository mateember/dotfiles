#!/bin/bash


packages=(alacritty alsa-utils ark base base-devel bat bluedevil blueman breeze-gtk breeze-plymouth btop chaotic-keyring chaotic-mirrorlist discover distrobox docker dolphin drkonqi dunst epson-inkjet-printer-escpr fastfetch fish flatpak-kcm fuse2 fuse2fs github-desktop grub-customizer gwenview hyprland hypridle hyprlock-git hyprpicker-git intel-ucode jre17-openjdk jre8-openjdk kate kdeconnect kde-gtk-config kdeplasma-addons kgamma kitty konsole krdp kscreen ksshaskpass kvantum kwallet-pam kwrited lact lib32-pipewire-jack lib32-pipewire-v4l2 linux-firmware linux-lts linux-lts-headers man-db dnsmasq nftables gnome-keyring modprobed-db nano network-manager-applet nwg-look ollama os-prober oxygen oxygen-sounds paru pavucontrol pipewire pipewire-pulse pipewire-jack pipewire-alsa plasma-browser-integration plasma-desktop plasma-disks plasma-firewall plasma-pa plasma-sdk plasma-systemmonitor plasma-thunderbolt plasma-vault plasma-welcome plasma-workspace-wallpapers plymouth plymouth-kcm print-manager pyenv qt6ct refind reflector rofi-wayland sane sane-airscan sddm sddm-kcm simple-scan starship steam swww system-config-printer tailscale tldr trash-cli v4l2loopback-dkms vim visual-studio-code-bin wacomtablet waybar wl-clipboard wlogout xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xone-dkms-git xorg-xhost xpadneo-dkms zoxide zsh efibootmgr grub os-prober sudo firewalld virt-manager qemu-desktop)




groups=(wheel vboxusers flatpak disk qemu kvm libvirtd libvirt sshd networkmanager audio video libvirtd docker)

ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc

sed -i '/en_US.UTF-8/s/^#//' "/etc/locale.gen"
sed -i '/hu_HU.UTF-8/s/^#//' "/etc/locale.gen"
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=hu" > /etc/vconsole.conf

echo -n "What do you want your hostname to be? "
read -r hostname
echo "$hostname" > /etc/hostname

pacman-key --init
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
sudo sed -i '/^\[multilib\]$/ { n; n; a\\n[chaotic-aur]\\nInclude = /etc/pacman.d/chaotic-mirrorlist\n}' "/etc/pacman.conf"
sed -i -E '/^#[[:space:]]*\[multilib\]/,/^#/ s/^#//' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '/ParallelDownloads/s/^#//' "/etc/pacman.conf"
sed -i "s/^ParallelDownloads = .*/ParallelDownloads = 10/" "/etc/pacman.conf"
pacman -Syyu
#packages_to_install=$(printf " %s" "${packages[@]}")
#packages_to_install=${packages_to_install:1}
#pacman -S --needed "$packages_to_install"
for package in "${packages[@]}"
do
    pacman -S --noconfirm --needed "$package"
done


grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchGRUB2
sed -i '/GRUB_DISABLE_OS_PROBER/s/^#//' /etc/default/grub
sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 splash\"/" "/etc/default/grub"
sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 amdgpu.ppfeaturemask=0xfff7ffff\"/" "/etc/default/grub"
sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 rootflags=subvol=\/archroot"/' "/etc/default/grub"
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable sddm
systemctl enable libvirtd
systemctl enable --now firewalld

firewall-cmd --zone=public --permanent --add-port=24642/udp
firewall-cmd --add-port=1714-1764/udp --permanent
firewall-cmd --add-port=1714-1764/tcp --permanent

sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers

passwd

useradd mate
chsh mate -s /usr/bin/fish
passwd mate

for group in "${groups[@]}"; do
    groupadd "$group"
    usermod -aG "$group" mate
done

mkinitcpio -P



