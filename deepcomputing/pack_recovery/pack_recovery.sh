#!/bin/bash
WORK_DIR=`pwd`
usage() {
  echo "Usage: ./pack_recovery.sh [die0_bootchain] [die1_bootchain]"
  echo "  parm1：(required),/path/die0_bootchain.bin"
  echo "  parm2：(optional),/path/die1_bootchain.bin"
  echo "eg:"
  echo "  ./pack_recovery.sh /path/die0_bootchain.bin"
  echo "  ./pack_recovery.sh /path/die0_bootchain.bin /path/die1_bootchain.bin"
}

if [ $# -eq 0 ] || [ $# -gt 2 ]; then
  usage
  exit 1
fi

secboot_line=`cat -n bootchain.config | grep in= | awk -F " " 'NR==1{print$1}'`
ddr_line=`cat -n bootchain.config | grep in= | awk -F " " 'NR==2{print$1}'`
sed -i "${secboot_line}s#.*# in=${WORK_DIR}/die0_sec_fw.bin#" bootchain.config
sed -i "${ddr_line}s#.*# in=${WORK_DIR}/ddr_fw.bin#"  bootchain.config

param1=$1
#output1_dir=$(dirname ${param1})
output0_name=$(basename ${param1})
output0=${WORK_DIR}/recovery_${output0_name}
source source.sh die0_autoboot.bin $param1 recovery_fw_die0.bin
cp -vf bootchain.config bootchain_recover.config
line_in=`cat -n bootchain_recover.config  | grep in=|awk '{print$1}' |tail -n 1`
sed -i "${line_in}s|in=.*|in=${WORK_DIR}/recovery_fw_die0.bin|" bootchain_recover.config
sed -i "2s|out=.*|out=${output0}|" bootchain_recover.config
./nsign bootchain_recover.config


if [ $# -eq 2 ]; then
  param2=$2
  output1_name=$(basename ${param2})
  output1=${WORK_DIR}/recovery_${output1_name}
  source source.sh die1_autoboot.bin ${param2} recovery_fw_die1.bin
  cp bootchain.config bootchain_recovery_die1.config
  sed -i "5s#.*# in=${WORK_DIR}/die1_sec_fw.bin#" bootchain_recovery_die1.config
  sed -i "s/59000000/79000000/g" bootchain_recovery_die1.config
  sed -i "s/80000000/79000000/g" bootchain_recovery_die1.config
  sed -i "59s#.*# in=${WORK_DIR}/recovery_fw_die1.bin#" bootchain_recovery_die1.config
  sed -i "s|out=.*|out=${output1}|" bootchain_recovery_die1.config
  ./nsign bootchain_recovery_die1.config
  echo result:$output1
fi
echo result:$output0

