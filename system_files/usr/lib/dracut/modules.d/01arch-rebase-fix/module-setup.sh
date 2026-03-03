#!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_multiple grep sed tr chmod chown touch sync rm
    inst_simple "$moddir/arch-rebase-fix-initrd.sh" /lib/dracut/hooks/pre-pivot/01-arch-rebase-fix.sh
}
