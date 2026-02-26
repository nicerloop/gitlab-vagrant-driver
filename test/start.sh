#!/bin/sh
set -e

# move to script folder
cd "$(dirname "$0")"

# load shared variables
. ".env"

# dns registration
grep -q "${GITLAB_HOST}" /etc/hosts || (
	echo "elevate to add ${GITLAB_HOST} to /etc/hosts"
	sudo sh -c "echo 127.0.0.1 ${GITLAB_HOST} >> /etc/hosts"
)

# start gitlab
docker compose up -d

# server URL
GITLAB_URL="http://${GITLAB_HOST}:${GITLAB_PORT}"

# wait for gitlab
start_time=$(date +%s)
while [ "$(curl -s -L -o /dev/null -w '%{http_code}' ${GITLAB_URL})" != "200" ]; do
  printf '.'
  sleep 5
done
printf '\n'
total_time=$(( $(date +%s) - start_time ))

echo "${GITLAB_URL} ready after ${total_time} seconds"
echo "user: root"
echo "password (copied to clipboard): ${GITLAB_ROOT_PASSWORD}"
echo "${GITLAB_ROOT_PASSWORD}" | pbcopy
open "${GITLAB_URL}"

# get host machine architecture

arch=$(uname -m)
case "$arch" in
x86_64) arch="amd64";;
aarch64) arch="arm64";;
esac

# register gitlab-runner

gitlab-runner register \
	--config "$(pwd)/gitlab-runner/config.toml" \
	--non-interactive \
	--url "${GITLAB_URL}" \
	--registration-token "${GITLAB_RUNNER_REGISTRATION_TOKEN}" \
	--tag-list windows,windows-$arch,windows-$arch-vagrant-virtualbox \
	--description "Windows Vagrant VirtualBox" \
	--builds-dir "builds" \
	--cache-dir "cache" \
	--executor "custom" \
	--custom-config-args "config" \
	--custom-config-args "box=bento/windows-11" \
	--custom-config-args "provider=virtualbox" \
	--custom-config-args "template=$(pwd)/Vagrantfile.vbox.win.erb" \
	--template-config "$(pwd)/../share/templates/gitlab-runner-config-template.toml"

open "${GITLAB_URL}/admin/runners/1"

# run gitlab runner

PATH=$PATH:$(pwd)/../bin gitlab-runner run \
	--config ./gitlab-runner/config.toml &

# https://docs.gitlab.com/user/profile/personal_access_tokens/#create-a-personal-access-token-programmatically
docker compose exec gitlab \
	gitlab-rails runner " \
		user = User.find_by(username: 'root'); \
		token = user.personal_access_tokens.create(name: 'Automation Token', scopes: [:api], expires_at: 1.year.from_now); \
		token.set_token('${GITLAB_ROOT_TOKEN}'); \
		token.save!; \
		puts token.token \
	"

# create test-project
curl --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{"name": "Test Project", "path": "test-project", "description": "Project description", "visibility": "public"}' \
  --url "${GITLAB_URL}/api/v4/projects"

open "${GITLAB_URL}/root/test-project"

# clone test-project
git clone ${GITLAB_URL}/root/test-project

# add pipeline
(
	cd test-project
	cat > .gitlab-ci.yml <<EOF
job:
  tags:
    - windows
  script:
    - echo "Hello, $GITLAB_USER_LOGIN!"
EOF
	git add .
	git commit -m "add pipeline"
	git push
)

open "${GITLAB_URL}/root/test-project/-/jobs/1"
