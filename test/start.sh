#!/bin/sh
set -e

# check dependencies
command -v docker >/dev/null 2>&1 || { echo >&2 "docker is required but not installed. Aborting."; exit 1; }
docker info >/dev/null 2>&1 || { echo >&2 "docker service is not running. Aborting."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo >&2 "docker-compose is required but not installed. Aborting."; exit 1; }
command -v gitlab-runner >/dev/null 2>&1 || { echo >&2 "gitlab-runner is required but not installed. Aborting."; exit 1; }
command -v playwright-cli >/dev/null 2>&1 || { echo >&2 "playwright-cli is required but not installed. Aborting."; exit 1; }
test -d /Applications/Google\ Chrome.app || { echo >&2 "Google Chrome is required but not installed. Aborting."; exit 1; }

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
echo "password: ${GITLAB_ROOT_PASSWORD}"
browser () {
  playwright-cli -s $GITLAB_BROWSER_SESSION "$@" >/dev/null
}
browser open --headed "${GITLAB_URL}/users/sign_in"
browser fill 'input[name="user[login]"]' "root"
browser fill 'input[name="user[password]"]' "${GITLAB_ROOT_PASSWORD}"
browser click "getByRole('button', { name: 'Sign In' })"
echo "logged in with temporary Playwright session"

# get host machine architecture

arch=$(uname -m)
case "$arch" in
x86_64) arch="amd64";;
aarch64) arch="arm64";;
esac

# prepare Vagrantfile templates to inject dns resolution
cp -v ../share/templates/Vagrantfile.vbox.win.erb .
patch -p 2 < Vagrantfile.vbox.win.erb.patch
cp -v ../share/templates/Vagrantfile.tart.mac.erb .
patch -p 2 < Vagrantfile.tart.mac.erb.patch

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
	--custom-config-args "image=bento/windows-11" \
	--custom-config-args "provider=virtualbox" \
	--custom-config-args "template=$(pwd)/Vagrantfile.vbox.win.erb" \
	--template-config "$(pwd)/../share/templates/gitlab-runner-config-template.toml"

browser tab-new "${GITLAB_URL}/admin/runners/1"

# run gitlab runner

PATH=$(pwd)/../bin:$PATH gitlab-runner run \
	--config ./gitlab-runner/config.toml &
echo $! > ./gitlab-runner/.pid

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

browser tab-new "${GITLAB_URL}/root/test-project"
sleep 5 && browser reload

# clone test-project
git clone http://root:${GITLAB_ROOT_TOKEN}@${GITLAB_HOST}:${GITLAB_PORT}/root/test-project

# add pipeline
(
	cd test-project
	git config --local user.name "Test User"
	git config --local user.email "test.user@localhost"
	cat > .gitlab-ci.yml <<EOF
job:
  tags:
    - windows
  script: |
    Write-Host "Hello from PowerShell"
EOF
	git add .
	git commit -m "add pipeline"
	git push
)

browser tab-new "${GITLAB_URL}/root/test-project/-/jobs/1"
sleep 5 && browser reload
