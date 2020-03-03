#!/bin/bash
# set -e: exit immediately if any command returns non-zero status
# set -o pipefail: check statuses of all commands in a pipeline
set -eo pipefail

# Before switching to the keybase user, make /mnt accessible to the bot.
chown -R keybase:keybase /mnt

# If START_KBFS isn't already true or false, check if there are any LOCATION
# variables that point to /keybase/
case $START_KBFS in
  true|false) ;;
  *)
    START_KBFS=false
    for v in CA_KEY_LOCATION LOG_LOCATION; do
      [[ ${!v} != /keybase/* ]] || START_KBFS=true
    done ;;
esac
export START_KBFS

# Ensure that critical variables are set, before trying to launch the bot.
for v in KEYBASE_PAPERKEY KEYBASE_USERNAME START_KBFS TEAMS; do
  if [[ -z ${!v} ]]; then
    echo "Please set $v in env.list and run make restart"
    exit 1
  fi
done

# Run everything else as the keybase user, passing through environment
# variables and entrypoint command-line arguments.
su-exec keybase:keybase /bin/bash -exc '

# Sign into the bot account using credentials provided by
# KEYBASE_USERNAME and KEYBASE_PAPERKEY.
keybase oneshot

if $START_KBFS; then
  # Start bot kbfs directly on /keybase (no redirector)
  KEYBASE_RUN_MODE=prod kbfsfuse /keybase &

  # Wait for kbfs to finish mounting before starting the bot.
  # If this fails, it will cause the entire startup to abort.
  for ((i = 0; i < 10; i++)); do
    [[ -d /keybase/team ]] && break || sleep 1
  done
fi

# Start the bot, defaulting to running the service.
keybaseca "${@:-service}"

# The following line passes through entrypoint arguments to this invocation of
# bash -c so that keybaseca can start with the same args (above).
' keybaseca "$@"
