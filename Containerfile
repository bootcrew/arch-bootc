FROM docker.io/archlinux/archlinux:latest
RUN pacman -Syu --noconfirm

# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

RUN pacman -Sy --noconfirm base dracut linux linux-firmware ostree btrfs-progs e2fsprogs xfsprogs dosfstools skopeo dbus dbus-glib glib2 ostree shadow && pacman -S --clean --noconfirm

RUN pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
    pacman-key --init && \
    pacman-key --lsign-key 3056513887B78AEB && \
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm && \
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm && \
    echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf && \
    echo -e '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf && \
    pacman -Syy

RUN pacman -S --noconfirm \
    reflector sudo bash fastfetch nano openssh unzip tar flatpak fuse2 fzf just wl-clipboard \
    libmtp nss-mdns samba smbclient networkmanager udiskie udisks2 udisks2-btrfs lvm2 cups cups-browsed cups-pdf system-config-printer hplip wireguard-tools \
    dosfstools cryptsetup bluez bluez-utils tuned tuned-ppd distrobox podman squashfs-tools zstd \
    ffmpeg ffmpegthumbnailer libcamera libcamera-tools libheif \
    amd-ucode intel-ucode efibootmgr shim mesa libva-intel-driver libva-mesa-driver \
    vpl-gpu-rt vulkan-icd-loader vulkan-intel vulkan-radeon apparmor xf86-video-amdgpu zram-generator \
    lm_sensors intel-media-driver git bootc openal ttf-twemoji curl

# Fix users and group after rebasing from non-arch image
RUN mkdir -p /usr/lib/systemd/system-preset /usr/lib/systemd/system
RUN echo -e '#!/bin/sh\n\
cat /usr/lib/sysusers.d/*.conf | \
grep -e "^g" | \
grep -v -e "^#" | \
awk "NF" | \
awk '\''{print $2}'\'' | \
grep -v -e "wheel" -e "root" -e "sudo" | \
xargs -I{} sed -i "/{}/d" "$1"' > /usr/libexec/arch-group-fix
RUN chmod +x /usr/libexec/arch-group-fix

RUN echo -e '[Unit]\n\
Description=Fix groups\n\
DefaultDependencies=no\n\
After=local-fs.target\n\
Before=sysinit.target systemd-resolved.service\n\
Wants=local-fs.target\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/libexec/arch-group-fix /etc/group\n\
ExecStart=/usr/libexec/arch-group-fix /etc/gshadow\n\
ExecStart=/usr/bin/systemd-sysusers\n\
\n\
[Install]\n\
WantedBy=sysinit.target' > /usr/lib/systemd/system/arch-group-fix.service

RUN echo -e "enable arch-group-fix.service" > /usr/lib/systemd/system-preset/01-arch-group-fix.preset

# Sudo for wheel group
RUN sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || \
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

RUN echo -e 'enable systemd-resolved.service' > /usr/lib/systemd/system-preset/91-resolved-default.preset
RUN echo -e 'L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' > /usr/lib/tmpfiles.d/resolved-default.conf
RUN systemctl preset systemd-resolved.service

RUN systemctl enable polkit.service && \
    systemctl enable arch-group-fix.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable cups.socket && \
    systemctl enable cups-browsed.service && \
    systemctl enable tuned-ppd.service && \
    systemctl enable tuned.service && \
    systemctl enable systemd-resolved.service && \
    systemctl enable systemd-resolved-varlink.socket && \
    systemctl enable systemd-resolved-monitor.socket && \
    systemctl enable bluetooth.service && \
    systemctl enable avahi-daemon.service

# https://github.com/bootc-dev/bootc/issues/1801
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" ostree bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img" && \
    pacman -S --clean --noconfirm

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv /opt /mnt /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -sT sysroot/ostree /ostree && ln -sT var/roothome /root && ln -sT var/srv /srv && ln -sT var/opt /opt && ln -sT var/mnt /mnt && ln -sT var/home /home && ln -sT ../var/usrlocal /usr/local && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

# Setup a temporary root passwd (changeme) for dev purposes
# RUN pacman -S whois --noconfirm
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# https://bootc-dev.github.io/bootc/bootc-images.html#standard-metadata-for-bootc-compatible-images
LABEL containers.bootc 1

RUN bootc container lint
