# ESWIN EIC7X SDK Build

This builds a complete RISC-V cross-compile toolchain for the ESWIN EIC7X SoC. 

## Prerequisites

Recommend OS: Ubuntu 16.04/18.04/20.04 x86_64

Install required additional packages:

```
$ sudo apt update
$ sudo apt-get install gdisk dosfstools build-essential libncurses-dev gawk flex bison \
     openssl libssl-dev tree dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf \
     device-tree-compiler xz-utils devscripts ccache debhelper wget curl pahole \
     libconfuse-dev mtools fastboot rsync
$ sudo apt install -y debootstrap devscripts qemu-user-static qemu-utils binfmt-support mmdebstrap
```

Additional docker:

```
sudo apt install docker.io
```

Get Eswin's RISC-V cross-compilation Docker Image:
```
wget http://120.92.155.32:8082/artifactory/virtOS/fml13v03-eswin/es_debian_compile_docker.tar
sudo docker load -i es_debian_compile_docker.tar
sudo docker pull multiarch/qemu-user-static
sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

## Fetch Code Instructions

Checkout this repository. Then checkout all of the linked submodules using:
```
$ git clone https://github.com/DC-DeepComputing/fml13v03.git

# To fetch the code along with all tags, run the following command to initialize and update all submodules.
# If you only need to compile, this step is not necessary. When you run the make commands, it will automatically pull the latest code as needed.
$ git submodule foreach --recursive 'git checkout $(git config -f $toplevel/.gitmodules submodule.$name.branch)'
```

## Quick Build Instructions

```
cd fml13v03
sudo docker run --rm --privileged -it -v "$(pwd)":/home/workspace -u root -w "/home/workspace" es_debian

source setenv.sh

Use the following method to start compiling:
    make_bootchain
    make_kernel
    make_debug_kernel
    make_desktop_images
    make_minimal_images
    make_all:bootchain kernel minimal_images

```

