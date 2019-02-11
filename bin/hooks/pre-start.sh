#!/bin/sh
# `pwd` should be /opt/mithril_api
APP_NAME="mithril_api"

if [ "${DB_MIGRATE}" == "true" ] && [ -f "./bin/${APP_NAME}" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/$APP_NAME command "Elixir.Core.ReleaseTasks" migrate
fi;

if [ "${LOAD_FIXTURES}" == "true" ] && [ -f "./bin/${APP_NAME}" ]; then
  echo "[WARNING] Loading fixtures!"
  ./bin/$APP_NAME command "Elixir.Core.ReleaseTasks" seed
fi;
