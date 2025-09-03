FROM docker.io/archlinux/archlinux:latest

COPY ./packages /packages

RUN pacman -Sy --noconfirm sudo base-devel && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*

# Create build user
RUN useradd -m --shell=/bin/bash build && usermod -L build && \
    cp /etc/sudoers /etc/sudoers.bak && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown build:build /packages

USER build
WORKDIR /home/build
RUN cp -r /packages /home/build && \
    chown build:build /home/build/packages && \
    cd /home/build/packages/bootc && makepkg -si --noconfirm && \
    cd /home/build/packages/bootupd && makepkg -si --noconfirm && \
    cd /home/build/packages/composefs-rs && makepkg -si --noconfirm

USER root
WORKDIR /

RUN userdel build && mv /etc/sudoers.bak /etc/sudoers

RUN pacman -Sy --noconfirm \
  dracut \
  linux \
  linux-firmware \
  ostree \
  composefs \
  systemd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  udev \
  cpio \
  zstd \
  binutils \
  dosfstools \
  conmon \
  crun \
  netavark \
  skopeo \
  dbus \
  dbus-glib \
  glib2 \
  shadow && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose \
       --kver "$(cat kernel_version.txt)" \
       --add ostree \
       --add-drivers "virtio virtio_blk virtio_pci virtio_ring virtio_net virtio_scsi virtio_balloon ahci ata_piix mptspi mptsas sd_mod scsi_mod nvme xfs ext4 btrfs vfat" \
       "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm kernel_version.txt

# Alter root file structure a bit for ostree
RUN mkdir -p /boot /sysroot /var/home && \
    rm -rf /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod -p '$6$AJv9RHlhEXO6Gpul$5fvVTZXeM0vC03xckTIjY8rdCofnkKSzvF5vEzXDKAby5p3qaOGTHDypVVxKsCE3CbZz7C3NXnbpITrEUvN/Y/' root && \
    rm -rf /packages

COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

# Necessary labels
LABEL containers.bootc 1
