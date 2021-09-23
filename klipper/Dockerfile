FROM python:3.9 as builder

ARG DEBIAN_FRONTEND=noninteractive

ARG USER=klippy
ARG HOME=/home/${USER}
ARG KLIPPER_VENV_DIR=${HOME}/klippy-env
ARG MOONRAKER_VENV_DIR=${HOME}/moonraker-env

RUN useradd -d ${HOME} -ms /bin/bash ${USER}
RUN apt-get update && \
    apt-get install -y locales git sudo wget curl gzip tar python2 virtualenv python-dev libffi-dev build-essential libncurses-dev libusb-dev gpiod python3-virtualenv python3-dev libopenjp2-7 python3-libgpiod liblmdb0 libsodium-dev

RUN sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

USER ${USER}
WORKDIR ${HOME}

### Klipper setup ###
RUN git clone https://github.com/KevinOConnor/klipper.git
RUN [ ! -d ${KLIPPER_VENV_DIR} ] && virtualenv -p python2 ${KLIPPER_VENV_DIR}
RUN ${KLIPPER_VENV_DIR}/bin/python -m pip install pip -U
RUN ${KLIPPER_VENV_DIR}/bin/pip install wheel
RUN ${KLIPPER_VENV_DIR}/bin/pip install -r klipper/scripts/klippy-requirements.txt

# Install moonraker
RUN git clone https://github.com/Arksine/moonraker.git
RUN [ ! -d ${MOONRAKER_VENV_DIR} ] && python3 -m venv ${MOONRAKER_VENV_DIR}
RUN ${MOONRAKER_VENV_DIR}/bin/python -m pip install pip -U
RUN ${MOONRAKER_VENV_DIR}/bin/pip install wheel gpiod

RUN ${MOONRAKER_VENV_DIR}/bin/pip install -r moonraker/scripts/moonraker-requirements.txt

FROM python:3.9-slim as image

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    git \
    gcc \
    locales \
    supervisor \
    nginx \
    curl libcurl4-openssl-dev libssl-dev \
    libjpeg62-turbo \
    libtiff5 \
    gpiod \
    libopenjp2-7 \
    rsync \
    liblmdb0 \
    libsodium-dev \
    zlib1g-dev \
    python2 \
    python3-libgpiod && \
    sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

ARG USER=klippy
ARG HOME=/home/${USER}
ENV CONFIG_DIR=${HOME}/.config
ENV KLIPPER_VENV_DIR=${HOME}/klippy-env
ENV MOONRAKER_VENV_DIR=${HOME}/moonraker-env

ARG DEVICE_GROUP=device
ARG DEVICE_GID=987

RUN useradd --user-group --no-log-init --shell /bin/false -m -d ${HOME} ${USER} && \
    groupadd -g ${DEVICE_GID} ${DEVICE_GROUP} && \
    usermod -a -G ${DEVICE_GROUP} ${USER} && \
    usermod -a -G tty ${USER} && \
    usermod -a -G dialout ${USER} && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /var/log/klipper && chown ${USER}:${USER} /var/log/klipper ${HOME} && \
    pip install --no-cache supervisord-dependent-startup gpiod


USER ${USER}
WORKDIR ${HOME}

RUN mkdir -p ${HOME}/gcode_files && \
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${HOME}/.moonraker_database

VOLUME ${HOME}/gcode_files
VOLUME ${CONFIG_DIR}

EXPOSE 7125

USER root

COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper ${HOME}/klipper
COPY --chown=${USER}:${USER} --from=builder ${KLIPPER_VENV_DIR} ${KLIPPER_VENV_DIR}
COPY --chown=${USER}:${USER} --from=builder ${HOME}/moonraker ${HOME}/moonraker
COPY --chown=${USER}:${USER} --from=builder ${MOONRAKER_VENV_DIR} ${MOONRAKER_VENV_DIR}
COPY --chown=${USER}:${USER} config ${CONFIG_DIR}

COPY klipper/supervisord.conf /etc/supervisord/conf.d/supervisord.conf
COPY klipper/*.ini /etc/supervisord/
CMD ["supervisord", "-c", "/etc/supervisord/conf.d/supervisord.conf"]
