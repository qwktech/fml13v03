WORK_DIR := ${$PWD}
PATH := /opt/riscv/bin:$$PATH
ARCH := riscv
CROSS_COMPILE := riscv64-unknown-linux-gnu-
RELEASE_TAG := EIC7X-2025.02
DDR_NAME := ddr_fw.bin
BOARD_NAME := FML13V03
DT_NAME := eic7702-deepcomputing-fml13v03
UBOOT_CONFIG := deepcomputing-fml13v03_defconfig
NPROC := `nproc`

# bootchain vars
SECBOOT_LINE=`cat -n ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config | grep in= | awk -F " " 'NR==1{print$1}'`
DDR_LINE=`cat -n ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config | grep in= | awk -F " " 'NR==2{print$1}'`
D2D_DIE0_LINE=`cat -n ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config | grep in= | awk -F " " 'NR==3{print$1}'`
D2D_DIE1_LINE=`cat -n ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die1.config | grep in= | awk -F " " 'NR==3{print$1}'`
UBOOT_LINE=`cat -n ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config | grep in= | awk -F " " 'NR==4{print$1}'`

# kernel vars
KDEB_PKGVERSION=$(make -C ${WORK_DIR}/${BOARD_NAME}/linux-eswin kernelversion)-$(date "+%Y.%m.%d.%H.%M")+
LINUX_DEFCONFIG=fml13v03_defconfig
BLK_DEV_INITRD=`cat ${WORK_DIR}/${BOARD_NAME}/linux-eswin/arch/riscv/configs/${LINUX_DEFCONFIG} | grep 'CONFIG_BLK_DEV_INITRD=y'`
ifeq (${BLK_DEV_INITRD},"")
	echo CONFIG_BLK_DEV_INITRD=y >>${WORK_DIR}/${BOARD_NAME}/linux-eswin/arch/riscv/configs/${LINUX_DEFCONFIG}
endif
KERNEL_VER1=$(cat ${WORK_DIR}/${BOARD_NAME}/linux-eswin/arch/riscv/configs/${LINUX_DEFCONFIG} | grep CONFIG_LOCALVERSION= |cut -d "=" -f 2|xargs)
KERNEL_VER2=`echo ${RELEASE_TAG} | cut -d "-" -f 2| tr "A-Z" "a-z"`
KERNEL_VER=${KERNEL_VER1}-${KERNEL_VER2}

test:
	echo ${WORK_DIR}

source-bootchain:
	mkdir -p ${WORK_DIR}/${BOARD_NAME}/output/
	rsync -au \
	  --chmod=u=rwX,go=rX \
	  --exclude .git \
	  --exclude .hg \
	  --exclude .bzr \
	  --exclude CVS \
	  ${WORK_DIR}/source/uboot-eswin ${WORK_DIR}/${BOARD_NAME}/
	rsync -au \
	  --chmod=u=rwX,go=rX \
	  --exclude .git \
	  --exclude .hg \
	  --exclude .bzr \
	  --exclude CVS \
	  ${WORK_DIR}/source/opensbi-eswin ${WORK_DIR}/${BOARD_NAME}/
	rsync -au \
	  --chmod=u=rwX,go=rX \
	  --exclude .git \
	  --exclude .hg \
	  --exclude .bzr \
	  --exclude CVS \
	  ${WORK_DIR}/source/firmware-eswin ${WORK_DIR}/${BOARD_NAME}/
	$(MAKE) -C ${WORK_DIR}/${BOARD_NAME}/uboot-eswin ${UBOOT_CONFIG}
	sed -i "s#\(CONFIG_DEFAULT_FDT_FILE=\)\"[^\"]*\"#\1\"eswin/${dt_name}.dtb\"#" \
	  ${WORK_DIR}/${BOARD_NAME}/uboot-eswin/.config
	$(MAKE) -C ${WORK_DIR}/${BOARD_NAME}/uboot-eswin -j ${NPROC}
	cp -av ${WORK_DIR}/${BOARD_NAME}/uboot-eswin/u-boot.bin ${WORK_DIR}/${board_name}/output/
	cp -av ${WORK_DIR}/${BOARD_NAME}/uboot-eswin/u-boot.dtb ${WORK_DIR}/${board_name}/output/
	$(MAKE) -C ${WORK_DIR}/${BOARD_NAME}/opensbi-eswin \
	  PLATFORM=eswin/eic770x \
	  FW_PAYLOAD=y \
	  FW_FDT_PATH=${WORK_DIR}/${BOARD_NAME}/output/u-boot.dtb \
          FW_PAYLOAD_PATH=${WORK_DIR}/${BOARD_NAME}/output/u-boot.bin \
          CHIPLET="BR2_CHIPLET_2" \
          CHIPLET_DIE_AVAILABLE="BR2_CHIPLET_1_DIE1_AVAILABLE" \
          MEM_MODE="BR2_MEMMODE_FLAT" \
          PLATFORM_CLUSTER_X_CORE="BR2_CLUSTER_4_CORE" \
          -j ${NPROC}
	cp -v \
	  ${WORK_DIR}/${BOARD_NAME}/opensbi-eswin/build/platform/eswin/eic770x/firmware/fw_payload.bin \
	  ${WORK_DIR}/${BOARD_NAME}/output/fw_payload.bin
	sed -i \
	  "s|out=.*|out=${WORK_DIR}/${board_name}/output/bootloader_${board_name}_die0.bin|" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config
	sed -i \
	  "s|out=.*|out=${WORK_DIR}/${board_name}/output/bootloader_${board_name}_die1.bin|" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die1.config
	#die0
	sed -i \
	  "${SECBOOT_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/die0_sec_fw.bin#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config
	sed -i \
	  "${DDR_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/${DDR_NAME}#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config
	sed -i \
	  "${D2D_DIE0_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/die0_d2d_init.bin#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config
	sed -i \
	  "${UBOOT_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/output/fw_payload.bin#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die0.config
	#die1
	sed -i \
	  "${SECBOOT_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/die1_sec_fw.bin#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die1.config
	sed -i \
	  "${DDR_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/${DDR_NAME}#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die1.config
	sed -i \
	  "${D2D_DIE1_LINE}s#.*# in=${WORK_DIR}/${BOARD_NAME}/firmware-eswin/die1_d2d_init.bin#" \
	  ${WORK_DIR}/${BOARD_NAME}/firmware-eswin/bootchain_die1.config
	${WORK_DIR}/${BOARD_NAME}/firmware-eswin/nsign bootchain_die0.config
	${WORK_DIR}/${BOARD_NAME}/firmware-eswin/nsign bootchain_die1.config

source-kernel:
	mkdir -p ${WORK_DIR}/${BOARD_NAME}/output/
	rsync -au \
	  --chmod=u=rwX,go=rX  \
	  --exclude .git \
	  --exclude .hg \
	  --exclude .bzr \
	  --exclude CVS \
	  ${WORK_DIR}/source/linux-eswin \
	  ${WORK_DIR}/${BOARD_NAME}/
	sed -i \
	  "/CONFIG_LOCALVERSION/d" \
	  ${WORK_DIR}/${BOARD_NAME}/linux-eswin/arch/riscv/configs/${LINUX_DEFCONFIG}
	make -C ${WORK_DIR}/${BOARD_NAME}/linux-eswin ${LINUX_DEFCONFIG}
	make -C ${WORK_DIR}/${BOARD_NAME}/linux-eswin -j ${NPROC} bindeb-pkg LOCALVERSION=${KERNEL_VER}
	mv -v ${WORK_DIR}/${BOARD_NAME}/linux-eswin/*.deb ${WORK_DIR}/${BOARD_NAME}/output/
