image_name := env("BUILD_IMAGE_NAME", "arch-bootc")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", "/tmp")
filesystem := env("BUILD_FILESYSTEM", "ext4")

# variant can be either "ostree" or "composefs-sealeduki"
# "ostree" here just means the image is "unsealed" and just gets tagged
variant := env("BUILD_VARIANT", "ostree")

namespace := env("BUILD_NAMESPACE", "bootcrew")
sudo := env("BUILD_ELEVATE", "sudo")
just_exe := just_executable()

enroll-secboot-key:
    #!/usr/bin/bash
    ENROLLMENT_PASSWORD=""
    SECUREBOOT_KEY=keys/db.cer
    "{{sudo}}" mokutil --timeout -1
    echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | "{{sudo}}" mokutil --import "$SECUREBOOT_KEY"
    echo 'At next reboot, the mokutil UEFI menu UI will be displayed (*QWERTY* keyboard input and navigation).\nThen, select "Enroll MOK", and input "bootcrew" as the password'

gen-secboot-keys:
    #!/usr/bin/env bash
    set -xeuo pipefail

    openssl req -quiet -newkey rsa:4096 -nodes -keyout keys/db.key -new -x509 -sha256 -days 3650 -subj '/CN=Arch Bootc Signature Database key/' -out keys/db.crt
    openssl x509 -outform DER -in keys/db.crt -out keys/db.cer

build-containerfile $image_name=image_name $variant=variant:
    #!/usr/bin/env bash
    set -xeuo pipefail

    {{sudo}} podman build -t "localhost/${image_name}_unsealed" .
    # TODO: we can make this a CLI program with better UX: https://github.com/bootc-dev/bootc/issues/1498
    {{sudo}} ./build-sealed "${variant}" "localhost/${image_name}_unsealed" "${image_name}" "keys"


fix-var-containers-selinux:
     {{sudo}} restorecon -RFv /var/lib/containers/storage

bootc *ARGS:
    {{sudo}} podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}


# installs on a physical target device
install-image $target_device $filesystem=filesystem:
    #!/usr/bin/env bash
    set -xeuo pipefail
    {{just_exe}} bootc install to-disk --composefs-backend --filesystem "${filesystem}" --wipe --bootloader systemd {{target_device}}

# installs onto an img file for testing in a VM
generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    {{just_exe}} bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd
