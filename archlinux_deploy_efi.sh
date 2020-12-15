#!/bin/bash

#env
target_dev=$1
target_stage=$2
usr_name=admin
usr_passwd=1234
root_passwd=1234
hostname=archlinux

function_stage_1()
{

umount -Rv /mnt

#part
parted $target_dev --script mklabel gpt \
										  mkpart primary 1MiB 100MiB \
										  mkpart primary 100MiB 100% \
										  set 1 boot on \
										  set 1 esp on \

#format
yes | mkfs.vfat $target_dev'1'
yes | mkfs.ext4 $target_dev'2'

#mount
mount $target_dev'2' /mnt
mkdir /mnt/boot
mount $target_dev'1' /mnt/boot

#package init
echo 'Server = http://mirror.csclub.uwaterloo.ca/archlinux/$repo/os/$arch' >/etc/pacman.d/mirrorlist
#package base (haveged is a workaround for ssh not available until login locally, somehow they decide to remove linux and dhcpcd from base)
pacstrap /mnt --needed base base-devel vim git openssh haveged zsh dnsmasq intel-ucode gnupg linux-headers linux linux-firmware dhcpcd
#package bootloader
pacstrap /mnt --needed grub efibootmgr
#package desktop

#gui x
#pacstrap /mnt --needed xorg xf86-video-intel xf86-video-vmware networkmanager

#kde
#pacstrap /mnt --needed sddm sddm-kcm plasma plasma-nm kde-applications konsole kwallet ark dolphin

#xfce
#pacstrap /mnt --needed lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4 xfce4-goodies

#gui apps
#pacstrap /mnt --needed chromium

#takeoff
genfstab -p -U /mnt >> /mnt/etc/fstab
cp -r /etc/zsh /mnt/etc/

#chroot
cp $0 /mnt
arch-chroot /mnt /$0 $target_dev chrooted

}

function_stage_2()
{

#config
echo $hostname >/etc/hostname
chmod +w /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL$/%wheel ALL=(ALL) ALL/g' /etc/sudoers
chmod -w /etc/sudoers
ln -sf /usr/share/zoneinfo/CST6CDT /etc/localtime
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf


#services
systemctl enable dhcpcd
systemctl enable sshd haveged

#service gui
#systemctl disable dhcpcd
#systemctl enable NetworkManager

#kde
#sddm --example-config > /etc/sddm.conf
#sed -i 's/^Current=.*$/Current=breeze/g' /etc/sddm.conf
#systemctl enable sddm
#TODO kde default setting https://unix.stackexchange.com/questions/209317/where-are-default-plasma-5-settings-stored

#xfce
#sed -i 's/^greeter-session=*$/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
#systemctl enable lightdm

#bootloader
#grub-install --target=i386-pc $target_dev
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

#account
useradd -m -G wheel -s /bin/zsh $usr_name
echo -e "$usr_passwd\n$usr_passwd" | passwd $usr_name
echo "#no zsh questions" > /home/$usr_name/.zshrc
echo -e "$root_passwd\n$root_passwd" | passwd root

#pacaur
pacman -Syu
pacman -S binutils make cmake gcc fakeroot pkg-config --noconfirm --needed
pacman -S expac jq gtest gmock fmt nlohmann-json meson git --noconfirm --needed

mkdir -p /tmp/pacaur_install
cd /tmp/pacaur_install
chmod 777 .

if [ ! -n "$(pacman -Qs auracle-git)" ]; then
    curl -o PKGBUILD "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=auracle-git"
    su $usr_name -c "makepkg PKGBUILD --skippgpcheck"
	#they changed .xz to .zst, it's getting annoying, so im just using * here
    pacman -U auracle-git-*.tar.* --noconfirm
fi

if [ ! -n "$(pacman -Qs pacaur)" ]; then
    curl -o PKGBUILD "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=pacaur"
    su $usr_name -c "makepkg PKGBUILD"
	#they changed .xz to .zst, it's getting annoying, so im just using * here
    pacman -U pacaur-*.tar.* --noconfirm
fi

cd ~
rm -r /tmp/pacaur_install

#rdp

exit
}

echo $target_dev $target_stage

#default_help
if [[ $target_dev == "" ]]
then
echo usage $0 /dev/sdx
exit
fi

if [ -b $target_dev ] && [[ $target_stage == "" ]]
then
echo stage 1
function_stage_1
exit
fi

if [ -b $target_dev ] && [[ $target_stage == "chrooted" ]]
then
echo stage 2
function_stage_2
umount /mnt/boot
umount /mnt
exit
fi
