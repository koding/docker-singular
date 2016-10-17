#!/bin/bash

set -o errexit

services="mongodb postgresql rabbitmq-server redis-server"

function start_services () {
  for name in $services; do
    service $name start
  done
}

function handle_interrupt() {
  ./run exec supervisorctl stop all
  ./run exec supervisorctl shutdown
  pkill mongod
  for name in $services; do
    service $name stop || :
  done
}

trap handle_interrupt INT TERM

function run_backend(){
  start_services
  ./run exec scripts/check-service-connectivity.sh
  nginx -c $(pwd)/nginx.conf
  ./run migrate up
  ./run exec supervisord -c supervisord.conf
  sleep 2
  tail --follow --lines +0 --quiet .logs/*.log
}

if [[ -z "$*" ]]; then
  ./configure --host localhost:8090 --hostname localhost
  run_backend
elif [[ "${1:0:1}" = '-' ]]; then
  ./configure $*
  run_backend
else
  exec "$@"
fi
