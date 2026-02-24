# Arch-base

Base [Arch Linux](https://archlinux.org/) container image with [bootc](https://github.com/bootc-dev/bootc) for usage in custom images. Similar for what is [Universal Blue main image](https://github.com/ublue-os/main/tree/main) to Fedora. 

- Images are build every day
- Codecs and drivers preinstalled
- Distrobox and flatpak preinstalled
- Fixes for some common problems with Arch bootc

I want also to thank [bootcrew](https://github.com/bootcrew) for making Arch bootc and [Hec](https://github.com/hecknt) for his "[Arch bootstraping](https://github.com/hecknt/archlinux-bootc/blob/5d1f578837ef8c4d1418ed7490a43a613b1a5d04/Containerfile#L1-L18)" that fixes some problems.

There is no Nvidia image right now 😕. If you want to make Nvidia image, just open PR.

If you want to make your custom image, just add this to your Containerfile:

```Containerfile
FROM ghcr.io/existingperson08/arch-base:latest
RUN pacman -Syu
```




