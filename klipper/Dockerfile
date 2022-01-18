FROM python:3.10-bullseye as builder

ARG DEBIAN_FRONTEND=noninteractive
ARG KLIPPER_BRANCH="master"
ARG MOONRAKER_BRANCH="master"

ARG USER=klippy
ARG HOME=/home/${USER}
ARG KLIPPER_VENV_DIR=${HOME}/klippy-env
ARG MOONRAKER_VENV_DIR=${HOME}/moonraker-env

RUN useradd -d ${HOME} -ms /bin/bash ${USER}
RUN apt-get update && \
    apt-get install -y locales git sudo wget curl gzip tar python2 virtualenv python-dev libffi-dev build-essential libncurses-dev libusb-dev gpiod python3-virtualenv python3-dev libopenjp2-7 python3-libgpiod liblmdb-dev libsodium-dev

RUN sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
RUN locale-gen

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

USER ${USER}
WORKDIR ${HOME}

### Klipper setup ###
RUN git clone --single-branch --branch ${KLIPPER_BRANCH} https://github.com/Klipper3d/klipper.git klipper
RUN [ ! -d ${KLIPPER_VENV_DIR} ] && virtualenv -p python2 ${KLIPPER_VENV_DIR}
RUN ${KLIPPER_VENV_DIR}/bin/python -m pip install pip -U
RUN ${KLIPPER_VENV_DIR}/bin/pip install wheel
RUN ${KLIPPER_VENV_DIR}/bin/pip install -r klipper/scripts/klippy-requirements.txt

# Install moonraker
RUN git clone --single-branch --branch ${MOONRAKER_BRANCH} https://github.com/Arksine/moonraker.git moonraker
RUN [ ! -d ${MOONRAKER_VENV_DIR} ] && python3 -m venv ${MOONRAKER_VENV_DIR}
RUN ${MOONRAKER_VENV_DIR}/bin/python -m pip install pip -U
RUN ${MOONRAKER_VENV_DIR}/bin/pip install wheel gpiod

RUN ${MOONRAKER_VENV_DIR}/bin/pip install -r moonraker/scripts/moonraker-requirements.txt

FROM python:3.10-slim-bullseye as image

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    curl \
    gcc \
    git \
    gpiod \
    iproute2 \
    libcurl4-openssl-dev \
    libjpeg-dev \
    liblmdb-dev \
    libopenjp2-7 \
    libsodium-dev \
    libssl-dev \
    libtiff5 \
    locales \
    python2 \
    python3-libgpiod \
    rsync \
    supervisor \
    zlib1g-dev && \
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
    pip install --no-cache supervisord-dependent-startup gpiod && \
    mkdir -p /usr/lib/python3 && \
    ln -s /usr/local/lib/python3.10/site-packages /usr/lib/python3/dist-packages

USER ${USER}
WORKDIR ${HOME}

RUN mkdir -p ${HOME}/gcode_files ${CONFIG_DIR} ${HOME}/.moonraker ${HOME}/.moonraker_database ${HOME}/.klipper_repo_backup ${HOME}/.moonraker_repo_backup

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
