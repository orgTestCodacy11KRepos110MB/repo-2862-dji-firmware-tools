#!/bin/bash
# -*- coding: utf-8 -*-

# Copyright (C) 2016,2017 Mefistotelis <mefistotelis@gmail.com>
# Copyright (C) 2018 Original Gangsters <https://dji-rev.slack.com/>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -eo pipefail
set -x

SKIP_EXTRACT=0
SKIP_REPACK=0
SKIP_CLEANUP=0
SKIP_COMPARE=0

if [ "$#" -lt "1" ]; then
    echo '### FAIL: No bin file name provided! ###'
    exit 4
fi

while [ "$#" -gt "0" ]
do
key="$1"

case $key in
  -se|--skip-extract)
    SKIP_EXTRACT=1
    ;;
  -sp|--skip-repack)
    SKIP_REPACK=1
    ;;
  -sn|--skip-cleanup)
    SKIP_CLEANUP=1
    ;;
  -sc|--skip-compare)
    SKIP_COMPARE=1
    ;;
  -on|--only-cleanup)
    SKIP_EXTRACT=1
    SKIP_REPACK=1
    SKIP_COMPARE=1
    ;;
  *)
    BINFILE="$key"
    ;;
esac
shift # past argument or value
done

if [ ! -f "${BINFILE}" ]; then
    echo '### FAIL: Input file not foumd! ###'
    echo "### INFO: Expected file \"${BINFILE}\" ###"
    exit 3
fi

TESTFILE="${BINFILE%.*}-test.sig"
SUPPORTS_MVFC_ENC=1
SUPPORTS_ANDR_TAR_BOOTIMG_ENC=1
SUPPORTS_ANDR_OTA_BOOTIMG_ENC=0
HAS_MVFC_ENC=
HAS_ANDRBOOTIMG_ENC=

if [ "${SKIP_COMPARE}" -le "0" ]; then
  echo '### TEST for dji_imah_fwsig.py and dji_mvfc_fwpak.py re-creation of binary file ###'
  # The test extracts firmware module from signed (and often encrypted)
  # DJI IMaH format, and then repacks it.
  # The test ends with success if the resulting BIN file is
  # exactly the same as input BIN file.
fi

BINFNAME=$(basename "${BINFILE}" | tr '[:upper:]' '[:lower:]')
if   [[ ${BINFNAME} =~ ^wm220[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2017-01 -k PUEK-2017-07"
  # allow change of 2 bytes from auth key name, 256 from signature
  HEAD_CHANGES_LIMIT=$((2 + 256))
  SUPPORTS_ANDR_OTA_BOOTIMG_ENC=0 # IAEK not published
elif [[ ${BINFNAME} =~ ^wm330[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2017-01 -k PUEK-2017-07"
  # allow change of 2 bytes from auth key name, 256 from signature
  HEAD_CHANGES_LIMIT=$((2 + 256))
  SUPPORTS_ANDR_OTA_BOOTIMG_ENC=0 # IAEK not published
elif [[ ${BINFNAME} =~ ^wm33[1-6][._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2017-01 -k PUEK-2017-11 -f" # PUEK not published, forcing extract encrypted
  # allow change of 2 bytes from auth key name, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 256 + 16+32))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc won't work without 1st stage
  SUPPORTS_ANDR_OTA_BOOTIMG_ENC=0 # IAEK not published
elif [[ ${BINFNAME} =~ ^wm100[._a].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2017-01 -k PUEK-2017-09 -f" # PUEK not published, forcing extract encrypted
  # allow change of 2 bytes from auth key name, 256 from signature
  HEAD_CHANGES_LIMIT=$((2 + 256))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc won't work without 1st stage
elif [[ ${BINFNAME} =~ ^(wm620|rc001)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2017-01 -k PUEK-2017-09 -f" # PUEK not published, forcing extract encrypted
  # allow change of 2 bytes from auth key name, 4 from enc checksum, 256 from signature
  HEAD_CHANGES_LIMIT=$((2 + 4 + 256))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc won't work without 1st stage
elif [[ ${BINFNAME} =~ ^(wm230)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-01 -k UFIE-2018-01"
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^(rc230)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-02 -k UFIE-2018-01 -f" # PRAK not published, forcing ignore signature fail
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^(wm170|wm231|wm232|gl170|pm430|ag500)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-02 -k UFIE-2020-04 -f" # PRAK not published, forcing ignore signature fail
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^(rcss170|rcjs170|rcs231|rc-n1-wm161b)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-02 -k TBIE-2020-04 -f" # PRAK not published, forcing ignore signature fail; modules not encrypted, boot images encrypted
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
  SUPPORTS_ANDR_TAR_BOOTIMG_ENC=1
elif [[ ${BINFNAME} =~ ^(wm24[0-6]|gl150|wm150|lt150)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-01 -k UFIE-2018-07"
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^(rc240)[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2018-02 -k UFIE-2018-07 -f" # PRAK not published, forcing ignore signature fail
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^wm160[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2019-09 -k UFIE-2019-11"
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
elif [[ ${BINFNAME} =~ ^wm161[._].*[.]sig$ ]]; then
  EXTRAPAR="-k PRAK-2019-09 -k UFIE-2019-11"
  # allow change of 2 bytes from auth key name, 4+4 from enc+dec checksum, 256 from signature, up to 16 chunk padding, 32 payload digest
  # TODO would be nice if we could eliminate padding discrepencies (these seem to happen in m0905 and m1100, for both WM160 and WM161)
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256 + 32+16))
  SUPPORTS_MVFC_ENC=0 # Decryption of 2nd lv FC enc not currently supported for this platform
else
  EXTRAPAR=""
  HEAD_CHANGES_LIMIT=$((2 + 4 + 4 + 256))
fi

if [ "${SKIP_EXTRACT}" -le "0" ]; then
  echo "### INFO: Input file \"${BINFILE}\" ###"
  # Remove files which will be created
  set +e
  rm ${TESTFILE%.*}_*.bin ${TESTFILE%.*}_*.ini 2>/dev/null
  set -e
  # Unsign/decrypt the module
  ./dji_imah_fwsig.py -vv ${EXTRAPAR} -u -i "${BINFILE}" -m "${TESTFILE%.*}" 2>&1 | tee "${TESTFILE%.*}_unsig.log"

  # FC modules have another stage of encryption which can be handled by MVFC script
  HAS_MVFC_ENC=$(sed -n 's/^modules=\([0-9]\{4\}[ ]\)*\(0305\|0306\).*$/\2/p' "${TESTFILE%.*}_head.ini" | head -n 1)
  if [ "${SUPPORTS_MVFC_ENC}" -le "0" ] && [ ! -z "${HAS_MVFC_ENC}" ]; then
    MODULE="${HAS_MVFC_ENC}"
    echo "### INFO: Found m${MODULE} inside, but 2nd stage MVFC decrypt disabled for this platform ###"
    HAS_MVFC_ENC=
  fi
  if [ ! -z "${HAS_MVFC_ENC}" ]; then
    MODULE="${HAS_MVFC_ENC}"
    echo "### INFO: Found m${MODULE} inside, doing 2nd stage MVFC decrypt ###"
    ./dji_mvfc_fwpak.py -vv dec -i "${TESTFILE%.*}_${MODULE}.bin" \
      -o "${TESTFILE%.*}_${MODULE}.decrypted.bin" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.log"
  fi

  # Some Android OTA modules contain boot images which have another stage of IMaH encryption
  HAS_ANDR_OTA_BOOTIMG_ENC=$(sed -n 's/^modules=\([0-9]\{4\}[ ]\)*\(0801\|0802\|0901\|1301\|2801\).*$/\2/p' "${TESTFILE%.*}_head.ini" | head -n 1)
  MODULE="${HAS_ANDR_OTA_BOOTIMG_ENC}"
  if [ "${SUPPORTS_ANDR_OTA_BOOTIMG_ENC}" -le 0 ] && [ ! -z "${HAS_ANDR_OTA_BOOTIMG_ENC}" ]; then
    echo "### INFO: Found m${MODULE} inside, but 2nd stage Android OTA bootimg decrypt disabled for this platform ###"
    HAS_ANDR_OTA_BOOTIMG_ENC=
  fi
  if [ ! -z "${HAS_ANDR_OTA_BOOTIMG_ENC}" ] && [[ $(file "${TESTFILE%.*}_${MODULE}.bin") != *"Java archive"* ]]; then
    echo "### INFO: Found m${MODULE} inside, but 2nd stage Android OTA bootimg decrypt disabled because it is not Java archive ###"
    HAS_ANDR_OTA_BOOTIMG_ENC=
  fi
  if [ ! -z "${HAS_ANDR_OTA_BOOTIMG_ENC}" ]; then
    echo "### INFO: Found m${MODULE} inside, doing 2nd stage Android OTA bootimg decrypt ###"
    unzip -q -o -d "${TESTFILE%.*}_${MODULE}" "${TESTFILE%.*}_${MODULE}.bin"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -u -i "${TESTFILE%.*}_${MODULE}/normal.img" \
      -m "${TESTFILE%.*}_${MODULE}.normal" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.normal_unsig.log"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -u -i "${TESTFILE%.*}_${MODULE}/recovery.img" \
      -m "${TESTFILE%.*}_${MODULE}.recovery" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.recovery_unsig.log"
  fi

  # Some Android TAR modules also contain boot images with another stage of IMaH encryption
  HAS_ANDR_TAR_BOOTIMG_ENC=$(sed -n 's/^modules=\([0-9]\{4\}[ ]\)*\(1301\).*$/\2/p' "${TESTFILE%.*}_head.ini" | head -n 1)
  MODULE="${HAS_ANDR_TAR_BOOTIMG_ENC}"
  if [ "${SUPPORTS_ANDR_TAR_BOOTIMG_ENC}" -le 0 ] && [ ! -z "${HAS_ANDR_TAR_BOOTIMG_ENC}" ]; then
    echo "### INFO: Found m${MODULE} inside, but 2nd stage Android TAR bootimg decrypt disabled for this platform ###"
    HAS_ANDR_TAR_BOOTIMG_ENC=
  fi
  if [ ! -z "${HAS_ANDR_TAR_BOOTIMG_ENC}" ] && [[ $(file "${TESTFILE%.*}_${MODULE}.bin") != *"tar archive"* ]]; then
    echo "### INFO: Found m${MODULE} inside, but 2nd stage Android TAR bootimg decrypt disabled because it is not TAR archive ###"
    HAS_ANDR_TAR_BOOTIMG_ENC=
  fi
  if [ ! -z "${HAS_ANDR_TAR_BOOTIMG_ENC}" ]; then
    echo "### INFO: Found m${MODULE} inside, doing 2nd stage Android TAR bootimg decrypt ###"
    mkdir -p "${TESTFILE%.*}_${MODULE}"
    tar -xf "${TESTFILE%.*}_${MODULE}.bin" --directory="${TESTFILE%.*}_${MODULE}"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -u -i "${TESTFILE%.*}_${MODULE}/ap.img" \
      -m "${TESTFILE%.*}_${MODULE}.ap" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.ap_unsig.log"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -u -i "${TESTFILE%.*}_${MODULE}/cp.img" \
      -m "${TESTFILE%.*}_${MODULE}.cp" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.cp_unsig.log"
  fi
fi

if [ "${SKIP_REPACK}" -le "0" ]; then
  # Remove file which will be created
  set +e
  if [ ! -z "${HAS_MVFC_ENC}" ]; then
    rm "${TESTFILE%.*}_${HAS_MVFC_ENC}.bin" 2>/dev/null
  fi
  rm "${TESTFILE}" 2>/dev/null
  set -e
  # We do not have private parts of auth keys used for signing - use OG community key instead
  # Different signature means we will get up to 256 different bytes in the resulting file
  # Additional 2 bytes of difference is the FourCC - two first bytes of it were changed
  sed -i "s/^auth_key=[0-9A-Za-z]\{4\}$/auth_key=SLAK/" "${TESTFILE%.*}_head.ini"
  # Encrypt and sign back to final format
  if [ ! -z "${HAS_MVFC_ENC}" ]; then
    MODULE="${HAS_MVFC_ENC}"
    MOD_FWVER=$(sed    -n "s/^Version:[ \t]*\([0-9A-Za-z. :_-]*\)$/\1/p" "${TESTFILE%.*}_${MODULE}.log" | head -n 1)
    MOD_TMSTAMP=$(sed  -n "s/^Time:[ \t]*\([0-9A-Za-z. :_-]*\)$/\1/p"    "${TESTFILE%.*}_${MODULE}.log" | head -n 1)
    ./dji_mvfc_fwpak.py enc -V "${MOD_FWVER}" -T "${MOD_TMSTAMP}" -t "${MODULE}" \
      -i "${TESTFILE%.*}_${MODULE}.decrypted.bin" -o "${TESTFILE%.*}_${MODULE}.bin"
  fi
  if [ ! -z "${HAS_ANDR_OTA_BOOTIMG_ENC}" ]; then
    MODULE="${HAS_ANDR_OTA_BOOTIMG_ENC}"
    sed -i "s/^auth_key=[0-9A-Za-z]\{4\}$/auth_key=SLAK/" "${TESTFILE%.*}_${MODULE}.normal_head.ini"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -s -i "${TESTFILE%.*}_${MODULE}.normal.img" \
      -m "${TESTFILE%.*}_${MODULE}.normal" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.normal_resig.log"
    sed -i "s/^auth_key=[0-9A-Za-z]\{4\}$/auth_key=SLAK/" "${TESTFILE%.*}_${MODULE}.recovery_head.ini"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -s -i "${TESTFILE%.*}_${MODULE}.recovery.img" \
      -m "${TESTFILE%.*}_${MODULE}.recovery" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.recovery_resig.log"
  fi
  if [ ! -z "${HAS_ANDR_TAR_BOOTIMG_ENC}" ]; then
    MODULE="${HAS_ANDR_TAR_BOOTIMG_ENC}"
    sed -i "s/^auth_key=[0-9A-Za-z]\{4\}$/auth_key=SLAK/" "${TESTFILE%.*}_${MODULE}.ap_head.ini"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -s -i "${TESTFILE%.*}_${MODULE}.ap.img" \
      -m "${TESTFILE%.*}_${MODULE}.ap" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.ap_resig.log"
    sed -i "s/^auth_key=[0-9A-Za-z]\{4\}$/auth_key=SLAK/" "${TESTFILE%.*}_${MODULE}.cp_head.ini"
    ./dji_imah_fwsig.py -vv ${EXTRAPAR} -s -i "${TESTFILE%.*}_${MODULE}.cp.img" \
      -m "${TESTFILE%.*}_${MODULE}.cp" 2>&1 | tee "${TESTFILE%.*}_${MODULE}.cp_resig.log"
  fi

  ./dji_imah_fwsig.py -vv ${EXTRAPAR} -s -i "${TESTFILE}" -m "${TESTFILE%.*}" 2>&1 | tee "${TESTFILE%.*}_resig.log"
fi

set +eo pipefail

if [ "${SKIP_COMPARE}" -le "0" ]; then
  # Compare converted with original
  if [ ! -z "${HAS_ANDR_OTA_BOOTIMG_ENC}" ]; then
    MODULE="${HAS_ANDR_OTA_BOOTIMG_ENC}"
    TEST_RESULT=$(cmp -l "${TESTFILE%.*}_${MODULE}/normal.img" "${TESTFILE%.*}_${MODULE}.normal.img" | wc -l)
    echo '### INFO: Counted '${TEST_RESULT}' differences in normal.img. ###'
    if [ ${TEST_RESULT} -gt ${HEAD_CHANGES_LIMIT} ]; then
      echo '### FAIL: Boot image normal.img changed during conversion! ###'
      exit 1
    fi
    TEST_RESULT=$(cmp -l "${TESTFILE%.*}_${MODULE}/recovery.img" "${TESTFILE%.*}_${MODULE}.recovery.img" | wc -l)
    echo '### INFO: Counted '${TEST_RESULT}' differences in recovery.img. ###'
    if [ ${TEST_RESULT} -gt ${HEAD_CHANGES_LIMIT} ]; then
      echo '### FAIL: Boot image recovery.img changed during conversion! ###'
      exit 1
    fi
  fi
  if [ ! -z "${HAS_ANDR_TAR_BOOTIMG_ENC}" ]; then
    TEST_RESULT=$(cmp -l "${TESTFILE%.*}_${MODULE}/ap.img" "${TESTFILE%.*}_${MODULE}.ap.img" | wc -l)
    echo '### INFO: Counted '${TEST_RESULT}' differences in ap.img. ###'
    if [ ${TEST_RESULT} -gt ${HEAD_CHANGES_LIMIT} ]; then
      echo '### FAIL: Boot image ap.img changed during conversion! ###'
      exit 1
    fi
    TEST_RESULT=$(cmp -l "${TESTFILE%.*}_${MODULE}/cp.img" "${TESTFILE%.*}_${MODULE}.cp.img" | wc -l)
    echo '### INFO: Counted '${TEST_RESULT}' differences in cp.img. ###'
    if [ ${TEST_RESULT} -gt ${HEAD_CHANGES_LIMIT} ]; then
      echo '### FAIL: Boot image cp.img changed during conversion! ###'
      exit 1
    fi
  fi
  TEST_RESULT=$(cmp -l "${BINFILE}" "${TESTFILE}" | wc -l)
  echo '### INFO: Counted '${TEST_RESULT}' differences. ###'
fi

if [ "${SKIP_CLEANUP}" -le "0" ]; then
  # Cleanup
  MODULE="${HAS_ANDRBOOTIMG_ENC}"
  if [ -d "${TESTFILE%.*}_${MODULE}" ]; then
    rm -rf "${TESTFILE%.*}_${MODULE}"
    rm "${TESTFILE%.*}_${MODULE}.*.img"
  fi
  rm "${TESTFILE}" ${TESTFILE%.*}_*.bin ${TESTFILE%.*}_*.ini
fi

if [ "${SKIP_COMPARE}" -le "0" ]; then
  if [ ${TEST_RESULT} == 0 ]; then
    echo '### SUCCESS: File identical after conversion. ###'
  elif [ ${TEST_RESULT} -le ${HEAD_CHANGES_LIMIT} ]; then
    echo '### SUCCESS: File matches, except signature. ###'
  elif [ ! -s "${TESTFILE}" ]; then
    echo '### FAIL: File empty or missing; creation faled! ###'
    exit 2
  else
    echo '### FAIL: File changed during conversion! ###'
    exit 1
  fi
fi

exit 0
