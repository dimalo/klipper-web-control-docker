FROM python:3.10-bullseye

ARG DEBIAN_FRONTEND=noninteractive
ARG KLIPPER_BRANCH="master"

ARG USER=klippy
ARG HOME=/home/${USER}
ARG KLIPPER_VENV_DIR=${HOME}/klippy-env

ENV PKGLIST="libffi-dev build-essential"
ENV PKGLIST="${PKGLIST} libncurses-dev"
ENV PKGLIST="${PKGLIST} libusb-dev"
ENV PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
ENV PKGLIST="${PKGLIST} stm32flash libnewlib-arm-none-eabi"
ENV PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0 pkg-config"

RUN useradd -d ${HOME} -ms /bin/bash ${USER}
RUN apt-get update && \
    apt-get install -y \
	locales \
	git \
	sudo \
	wget \
	curl \
	gzip \
	tar \
	${PKGLIST}

RUN sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen
RUN python -m pip install pip -U

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

USER ${USER}
WORKDIR ${HOME}

### Klipper setup ###
RUN git clone --single-branch --branch ${KLIPPER_BRANCH} https://github.com/Klipper3d/klipper.git klipper
RUN [ ! -d ${KLIPPER_VENV_DIR} ] && python3 -m venv ${KLIPPER_VENV_DIR}
RUN ${KLIPPER_VENV_DIR}/bin/pip install wheel

WORKDIR ${HOME}/klipper
RUN ${KLIPPER_VENV_DIR}/bin/pip install -r scripts/klippy-requirements.txt
RUN ${KLIPPER_VENV_DIR}/bin/python klippy/chelper/__init__.py
RUN ${KLIPPER_VENV_DIR}/bin/python -m compileall klippy

WORKDIR ${HOME}/klipper

CMD ["bash"]