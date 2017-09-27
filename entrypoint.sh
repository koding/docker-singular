#!/bin/bash

set -o errexit

if [[ -n "$DEBUG" ]]; then
  set -o xtrace
fi

services="mongodb postgresql rabbitmq-server redis-server"

function start_services () {
  for name in $services; do
    service $name start
  done
}

function init_mongodb() {
  chown --recursive mongodb:mongodb /var/lib/mongodb
  local tarball_url="https://github.com/koding/koding/raw/master/install/docker-mongo/default-db-dump.tar.bz2"

  curl --silent --location $tarball_url |
    tar --extract --bzip2 --directory /tmp/

  service mongodb start
  /opt/wait.sh mongo

  mongorestore /tmp/dump

  rm -rf /tmp/dump
}

function init_postgresql() {
  chown --recursive postgres:postgres /var/lib/postgresql
  su postgres -c "/usr/lib/postgresql/9.3/bin/initdb --pgdata /var/lib/postgresql/9.3/main"
  service postgresql start
  su postgres -c "go/src/socialapi/db/sql/definition/create.sh go/src/socialapi/db/sql"
  ./run migrate up
}

function init_databases() {
  [ -z "`ls --almost-all /var/lib/mongodb/`" ] && init_mongodb || :
  [ -z "`ls --almost-all /var/lib/postgresql/`" ] && init_postgresql || :
}

function handle_interrupt() {
  ./run exec supervisorctl stop all || :
  ./run exec supervisorctl shutdown || :
  pkill mongod
  for name in $services; do
    service $name stop || :
  done
}

trap handle_interrupt INT TERM

function run_backend(){
  init_databases
  start_services
  ./run is_ready
  ./run migrate up
  ./run exec supervisord -c supervisord.conf
  sleep 2
  tail --follow --lines +0 --quiet .logs/*.log
}

if [[ -z "$*" ]]; then
  ./configure --host localhost --hostname localhost --publicPort 80
  go/build.sh
  ./run exec make klient
  run_backend
elif [[ "${1:0:1}" = '-' ]]; then
  ./configure "$@"
  go/build.sh
  ./run exec make klient
  run_backend
else
  exec "$@"
fi
