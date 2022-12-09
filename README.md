![Mainsail Multiarch Image CI](https://github.com/dimalo/klipper-web-control-docker/workflows/Mainsail%20Multiarch%20Image%20CI/badge.svg)
![Klipper Moonraker Multiarch Image CI](https://github.com/dimalo/klipper-web-control-docker/workflows/Klipper%20Moonraker%20Multiarch%20Image%20CI/badge.svg)

# klipper-web-control-docker

__Caution__

If you used klipper-web-control-docker before, mind the changes in `docker-compose.yml` in accordance with the changed [moonraker standard](https://moonraker.readthedocs.io/en/latest/installation/#data-folder-structure).
Volume bindings were changed from `gcode_files:/home/klippy/gcode_files` to `gcodes:/home/klippy/printer_data/gcodes` and from `./config:/home/klippy/.config` to `./config:/home/klippy/printer_data/config`. `moonraker_data:/home/klippy/.moonraker` was removed.

__Klipper with Moonraker shipped with Fluidd and/or Mainsail__

- get your printer to the next level!
- Docker Compose config and Dockerfiles provided!
- Build with Github actions and deployed to https://hub.docker.com/u/dimalo
- Docker multiarch builds with best practices

## Features
- Dockerhub images support x64, ARM64, ARM32v7 & ARM32v6
- Docker multistage builds for optimized image sizes
- fully integrated klipper image with moonraker enabled
  - startup management with supervisord & dependent startup (klipper starts first, then only if klipper is running moonraker is started)
- collection of useful klipper macros [see client_macros.cfg](./config/client_macros.cfg)
  - Nozzle prime line with random Y starting point
    
    Don't use the same starting point for priming to reduce bed wear!
  
  - safe filament load / unload / change, which checks for sufficient (configurable) nozzle temperature

  - best practice start gcode:

    Please modify this to your needs! This macro works well on my cartesian and core xy machines and only homes Z as soon as the nozzle is hot, so leftover extrusions don't smash into the bed when they're cold.

    Example for PrusaSlicer start gcode:

    ```
    ; Making sure PrusaSlicer doesn't inject heatup gcode...
    M104 S0
    M190 S0
    ; Run START_PRINT macro
    START_PRINT T_BED=[first_layer_bed_temperature] T_EXTRUDER=[first_layer_temperature]
    ```

  - several versions of pause/cancel/end, to either present the toolhead or the print (and get the toolhead out of the way) - ___check the defaults!___

  - park toolhead with ```M125``` (default X25 Y0)

  - support delay with display output with ```COUNTDOWN```

  ___Please be careful to not run the macros without making sure they work with your printer!___
- collection of calibration macros (for example manual bed leveling) [see calibration_macros.cfg](./config/calibration_macros.cfg)
- complete Klipper setup with web control client
  - supports [Fluidd](https://github.com/cadriel/fluidd)
  - supports [Mainsail](https://github.com/meteyou/mainsail)
  - you can even run both in parallel!
- only your printer.cfg is required!
  - the services start without it, so you can supply your config through the web UI
  - you can mount your config file to /home/klippy/.config/printer.cfg, and klipper will pick it up after a restart

## Getting started

___Prerequisites:___
- _Your klipper host machine runs Linux or MacOS (Windows was not tested yet)_
    - (MacOS) Currently it is not possible to expose serial devices to a container in MacOS Docker. This is a known issue with Docker (https://github.com/docker/for-mac/issues/900)
- _You have docker and docker-compose installed on your machine_
- _You have flashed your printer with the appropriate .bin_
- _You have your printer connected to your machine and you know it's serial mount point (e.g. /dev/ttyACM0 or /dev/ttyUSB0)_
- _ARM32v6 (Raspberry Pi Zero and 1) requires [Docker 20](https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script). Fluidd is not yet supported_

### Install the services

1. clone this repository and open it or navigate to it in your terminal
1. modify docker-compose.yml to your needs
    - set serial port of your printer
    - mount printer.cfg if already prepared (else you will be able to set it up later as well...)
1. run ```docker-compose pull && docker-compose up``` if you want to use the provided dockerhub images, else run ```docker-compose up``` to first build them on your host
1. watch the services being set up
    - make sure you have no port conflicts on 7125, 8010 and 8011 
    - make sure klipper and moonraker started
    - leave the compose session running
1. test the frontends
    - http://localhost:8010
    - http://localhost:8011
1. configure your printer
    - modify / upload printer.cfg, if not mounted already
    - check if klipper is able to connect to the printer
    - follow klippers documentation to test your printers functionality

### If things are running fine now...
Quit the compose session with ```Ctrl+C```and run ```docker-compose up -d```.

__Happy 3D Printing!__

### If things are not running...

__No serial connection:__

Check the permissions on the serial device in the klipper host.

```ls -lsa /dev/ttyACM0```

Supply the group permissions to the docker-compose config in docker-compose.yml build args for klipper.

Run ```docker-compose build```

After build run ```docker-compose up -d``` and see if it works.

## Features not implemented or not tested (yet)
- compiling klipper.bin for your printer (will need compile tools which bloat the image so this will likely not be implemented)
- automatic updates for klipper/moonraker (partly working as repos are getting updated but no dependency installs happen - update the container with ```docker-compose pull``` instead)
- automatic updates for the frontend (update the container with ```docker-compose pull``` instead)
- CI pipeline to build images as upstream repos change

## Credits
- where I found some of the macros
  - [https://github.com/fl0r1s/klipper_config](https://github.com/fl0r1s/klipper_config)
- [Klipper](https://github.com/KevinOConnor/klipper)
- [Moonraker](https://github.com/Arksine/moonraker)
- [Fluidd](https://github.com/cadriel/fluidd)
- [Mainsail](https://github.com/meteyou/mainsail)
- awesome global RepRap open source community!
