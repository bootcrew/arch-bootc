image_name := env("BUILD_IMAGE_NAME", "arch-bootc")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "ext4")
ovmf_code := env("OVMF_CODE_PATH", "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd")
ovmf_vars_source := env("OVMF_VARS_SOURCE", "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd")
ovmf_vars := env("OVMF_VARS_PATH", "./OVMF_VARS.fd")

build-containerfile $image_name=image_name:
    sudo podman build -t "${image_name}:latest" .

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    just bootc install to-disk --composefs-native --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd

# Run the VM with QEMU using OVMF for UEFI support
# You must install qemu and edk2-ovmf packages for this to work
run-qemu-vm $ovmf_code=ovmf_code $ovmf_vars_source=ovmf_vars_source $ovmf_vars=ovmf_vars:
    if [ ! -e "{{ovmf_vars}}" ]; then cp "{{ovmf_vars_source}}" "{{ovmf_vars}}"; fi
    qemu-system-x86_64 \
        -m 8G \
        -smp 4 \
        -enable-kvm \
        -drive if=pflash,format=raw,readonly=on,file="{{ovmf_code}}" \
        -drive if=pflash,format=raw,file="{{ovmf_vars}}" \
        -drive file=./bootable.img,format=raw \
        -device virtio-vga \
        -display gtk \
        -nic user,hostfwd=tcp::2222-:22 \
        -usbdevice tablet
