#!/bin/sh

NEWROOT="${NEWROOT:-/sysroot}"

[ -f "${NEWROOT}/etc/remove-fstab-root.stamp" ] && exit 0
[ -f "${NEWROOT}/etc/fstab" ] || exit 0

root_UUID=$(sed -n 's/.*root=UUID=\([^[:space:]]\{36\}\).*/UUID=\1/p' /proc/cmdline)

if [ -n "$root_UUID" ] && grep -E -q "^$root_UUID[[:space:]]/[[:space:]]" "${NEWROOT}/etc/fstab" && findmnt "${NEWROOT}" | grep -q composefs && [ ! -L "${NEWROOT}/boot/grub2/grub.cfg" ]; then
    tmp="/tmp/fstab.tmp.$$"
    trap 'rm -f "$tmp"' EXIT INT TERM
    sed '/^'"$root_UUID"'[[:space:]]\/[[:space:]]/d' "${NEWROOT}/etc/fstab" > "$tmp"
    mv "$tmp" "${NEWROOT}/etc/fstab"
    chown root:root "${NEWROOT}/etc/fstab"
    chmod 0644 "${NEWROOT}/etc/fstab"
    touch "${NEWROOT}/etc/remove-fstab-root.stamp"
    sync
fi
