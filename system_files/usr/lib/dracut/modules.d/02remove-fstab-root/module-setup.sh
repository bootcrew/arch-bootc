#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_multiple grep sed chmod chown touch sync findmnt mv
    inst_simple "$moddir/remove-fstab-root-initrd.sh" /lib/dracut/hooks/pre-pivot/02-remove-fstab-root.sh
}
