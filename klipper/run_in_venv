#!/bin/bash
VENV=$1
if [ -z $VENV ]; then
    echo "usage: run_in_venv [virtualenv_path] CMDS"
    exit 1
fi
. ${VENV}/bin/activate
shift 1
echo "Executing $@ in ${VENV}"
exec "$@"
deactivate
