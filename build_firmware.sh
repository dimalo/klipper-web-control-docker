#!zsh

BASE=$(pwd)
echo $BASE
TARGET=cheetah
BUILD_DIR=${BASE}/build
CONFIG_NAME=".config_${TARGET}"
CONFIG_PATH=${BUILD_DIR}/${CONFIG_NAME}
touch ${CONFIG_PATH}
OUT_DIR=${BUILD_DIR}/klipper_build_${TARGET}
mkdir -p ${BUILD_DIR}
CONTAINER=$(docker run -d -v ${CONFIG_PATH}:/home/klippy/klipper/.config -v ${BUILD_DIR}:/home/klippy/klipper/out klipper-builder sleep infinity)
docker exec -it ${CONTAINER} make menuconfig
docker exec ${CONTAINER} make
#docker exec ${CONTAINER} make flash
docker stop ${CONTAINER}
docker rm ${CONTAINER}