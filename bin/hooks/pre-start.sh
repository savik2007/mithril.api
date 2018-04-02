#!/bin/sh
# `pwd` should be /opt/mithril_api
APP_NAME="mithril_api"

if [ "${DB_MIGRATE}" == "true" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/$APP_NAME command "Elixir.Mithril.ReleaseTasks" migrate
fi;

if [ "${LOAD_FIXTURES}" == "true" ]; then
  echo "[WARNING] Loading fixtures!"
  ./bin/$APP_NAME command "Elixir.Mithril.ReleaseTasks" seed
fi;
