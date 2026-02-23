#!/bin/sh
. ".env"
killall gitlab-runner
rm -r -f gitlab-runner
docker compose down --volumes
rm -r -f test-project
grep -q "${GITLAB_HOST}" /etc/hosts && sudo sh -c "sed -i .old -e '/${GITLAB_HOST}/d' /etc/hosts"
