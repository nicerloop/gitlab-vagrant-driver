#!/bin/sh
. ".env"
browser="playwright-cli -s $GITLAB_BROWSER_SESSION"
$browser close
rm -r -f .playwright-cli
kill $(cat ./gitlab-runner/.pid)
rm -r -f gitlab-runner
rm -f Vagrantfile.*.erb
docker compose down --volumes
rm -r -f test-project
grep -q "${GITLAB_HOST}" /etc/hosts && (
	echo "elevate to remove ${GITLAB_HOST} from /etc/hosts"
	sudo sh -c "sed -i .old -e '/${GITLAB_HOST}/d' /etc/hosts"
)
